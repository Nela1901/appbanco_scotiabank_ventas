import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../model/cliente.dart';
import 'package:flutter/foundation.dart'; // Para compute
import '../model/database_service.dart';
import '../navigation/app_routes.dart';

class CarteraViewModel extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _db = DatabaseService();

  List<Cliente> _clientes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _filtroActual = 'Todos';
  String _filtroAsesor = 'Todos';
  String _searchQuery = "";
  String _ultimaActualizacion = "Pendiente";
  List<String> _manualOrderIds = [];
  List<Map<String, dynamic>> _queueVisitas = [];
  List<Map<String, dynamic>> _queueSolicitudes = [];
  bool _isOffline = false;
  List<Cliente> _rutaOptimizada = [];
  List<LatLng> _geocercaPuntos = []; // HU-09: Polígono de zona
  Map<String, dynamic>? _posicionConsolidada;
  List<Map<String, dynamic>> _historialCreditos = [];
  Map<String, dynamic>? _ofertaPreaprobada;
  int _alertasNoLeidas = 0;
  List<Map<String, dynamic>> _campanasActivas = [];
  Map<String, dynamic>? _resultadoPreEvaluacion;
  List<Map<String, dynamic>> _historialSolicitudes = [];
  List<Map<String, dynamic>> _solicitudesTablero = [];
  List<Map<String, dynamic>> _carteraVencida = [];
  List<Map<String, dynamic>> _monitoreoAsesores = [];
  List<Map<String, dynamic>> _productividadAsesores = [];
  Map<String, dynamic>? _resultadoBuro;
  
  // M6: Estado de documentos por tipo
  final Map<String, String> _documentosEstado = {
    'dni_anverso': 'OBLIGATORIO',
    'dni_reverso': 'OBLIGATORIO',
    'foto_negocio': 'OBLIGATORIO',
    'foto_asesor_cliente': 'OBLIGATORIO',
    'recibo_servicios': 'PENDIENTE',
  };

  Timer? _debounce;
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _solicitudesRealtimeSubscription;
  StreamSubscription? _monitoreoSubscription;

  CarteraViewModel() {
    _loadLastSyncTime();
    _loadManualOrder();
    _initConnectivityMonitor();
    _initRealtimeAlerts();
    fetchCampanas(); // RF-40
    fetchSolicitudesMes(); // RF-51
    _initRealtimeSolicitudes(); // RF-68
  }

  List<Cliente> get clientes {
    Iterable<Cliente> filtrados = _clientes;

    // RF-11: Aplicación de filtros de categorías
    if (_filtroActual != 'Todos') {
      if (_filtroActual == 'Visitados') {
        filtrados = filtrados.where((c) => c.visitado);
      } else if (_filtroActual == 'En mora') {
        filtrados = filtrados.where((c) => c.tipoGestion.toUpperCase() == 'RECUPERACION MORA');
      } else if (_filtroActual == 'Renovaciones') {
        filtrados = filtrados.where((c) => c.tipoGestion.toUpperCase() == 'RENOVACION');
      } else if (_filtroActual == 'Nuevas') {
        filtrados = filtrados.where((c) => c.tipoGestion.toUpperCase() == 'NUEVA SOLICITUD');
      } else {
        filtrados = filtrados.where((c) => c.estado.toLowerCase() == _filtroActual.toLowerCase());
      }
    }

    // Filtro por Asesor (Solo para Supervisor/Admin)
    if (_filtroAsesor != 'Todos') {
      filtrados = filtrados.where((c) => c.nombreAsesor == _filtroAsesor);
    }

    // RF-12: Búsqueda rápida por nombre o documento
    if (_searchQuery.isNotEmpty) {
      filtrados = filtrados.where((c) => 
        c.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        // Buscamos dentro de los últimos 4 dígitos. Si el doc es más corto, buscamos en todo.
        (c.numeroDocumento.length >= 4 
          ? c.numeroDocumento.substring(c.numeroDocumento.length - 4).contains(_searchQuery)
          : c.numeroDocumento.contains(_searchQuery))
      );
    }

    // RF-09 y HU-06: Ordenamiento automático y manual
    final listaFinal = filtrados.toList();
    listaFinal.sort((a, b) {
      // Los visitados siempre al fondo
      if (a.visitado != b.visitado) return a.visitado ? 1 : -1;

      // Si existe un reordenamiento manual guardado localmente (RF-16)
      if (_manualOrderIds.isNotEmpty) {
        int idxA = _manualOrderIds.indexOf(a.id);
        int idxB = _manualOrderIds.indexOf(b.id);

        // Si ambos están en el orden manual, respetamos ese orden
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        // Los nuevos elementos que no están en el orden guardado se ponen antes de los visitados
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
      }

      // Por defecto: Score de prioridad descendente (RF-15)
      return b.scorePrioridad.compareTo(a.scorePrioridad);
    });

    return listaFinal;
  }

  bool get isLoading => _isLoading;
  String get filtroActual => _filtroActual;
  String get filtroAsesor => _filtroAsesor;
  bool get isOffline => _isOffline;

  /// RF-06: Obtiene la lista de nombres de asesores presentes en la cartera cargada
  List<String> get asesoresEnCartera {
    final set = _clientes
        .map((c) => c.nombreAsesor)
        .where((n) => n != null && n!.isNotEmpty)
        .cast<String>()
        .toSet();
    final list = set.toList();
    list.sort();
    return ['Todos', ...list];
  }

  void setFiltroAsesor(String val) {
    _filtroAsesor = val;
    notifyListeners();
  }

  // El progreso del día siempre se calcula sobre el total real del día (no filtrado)
  double get progresoDia => _clientes.isEmpty ? 0 : _clientes.where((c) => c.visitado).length / _clientes.length;

  int get pendientesSyncCount => _queueVisitas.length;
  String get ultimaActualizacion => _ultimaActualizacion;
  List<Cliente> get rutaOptimizada => _rutaOptimizada;
  Map<String, dynamic>? get posicionConsolidada => _posicionConsolidada;
  List<Map<String, dynamic>> get historialCreditos => _historialCreditos;
  Map<String, dynamic>? get ofertaPreaprobada => _ofertaPreaprobada;
  int get alertasNoLeidas => _alertasNoLeidas;
  List<Map<String, dynamic>> get campanasActivas => _campanasActivas;
  Map<String, dynamic>? get resultadoPreEvaluacion => _resultadoPreEvaluacion;
  List<Map<String, dynamic>> get historialSolicitudes => _historialSolicitudes;
  List<Map<String, dynamic>> get solicitudesTablero => _solicitudesTablero;
  List<Map<String, dynamic>> get carteraVencida => _carteraVencida;
  List<Map<String, dynamic>> get monitoreoAsesores => _monitoreoAsesores;
  List<Map<String, dynamic>> get productividadAsesores => _productividadAsesores;
  Map<String, String> get documentosEstado => _documentosEstado;
  Map<String, dynamic>? get resultadoBuro => _resultadoBuro;

  // RF-59: Interpretación automática del resultado de buró
  String get interpretacionBuro {
    if (_resultadoBuro == null) return "";
    final res = _resultadoBuro!;
    final enLista = res['en_lista_negra'] ?? false;
    
    return "El cliente tiene historial en ${res['num_entidades'] ?? 0} entidades con deuda total de S/ ${res['deuda_total'] ?? '0.00'}. "
           "Mora máxima histórica: ${res['mora_maxima'] ?? 0} días. "
           "Recomendación: ${enLista ? 'Rechazar por presencia en listas negativas.' : 'Proceder con la evaluación.'}";
  }

  // RF-11: Los contadores deben reflejar lo que el usuario ve (la lista filtrada)
  int get totalAsignados => clientes.length;
  int get visitadosTotal => clientes.where((c) => c.visitado).length;
  int get pendientesTotal => clientes.where((c) => !c.visitado).length;

  // HU-04: Texto de resumen para el encabezado
  String get resumenHeader => "$totalAsignados clientes · $visitadosTotal visitados · $pendientesTotal pendientes";

  // HU-30: Monto total vencido
  double get totalMora => _carteraVencida.fold(0.0, (sum, item) => sum + (item['monto_vencido'] ?? 0.0));

  // RF-47: Cálculo de cuota mensual (Amortización Francesa)
  Map<String, double> calcularSimulacion(double monto, double tea, int plazo) {
    if (monto <= 0 || tea <= 0 || plazo <= 0) return {};
    
    double teaDecimal = tea / 100;
    // Tasa mensual equivalente = (1 + TEA)^(1/12) - 1
    double tem = pow(1 + teaDecimal, 1 / 12) - 1;
    
    // Cuota mensual = Monto x Tasa mensual / (1 - (1 + Tasa mensual)^(-Plazo en meses))
    double cuota = (monto * tem) / (1 - pow(1 + tem, -plazo));
    double totalPagar = cuota * plazo;
    double costoFinanciero = totalPagar - monto;

    return {
      'cuota': cuota,
      'totalPagar': totalPagar,
      'costoFinanciero': costoFinanciero,
    };
  }

  // RF-51/52: Consulta e indicadores mensuales
  Future<void> fetchSolicitudesMes() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1).toIso8601String();
      
      final data = await _supabase
          .from('solicitudes_credito')
          .select()
          .eq('asesor_id', userId)
          .gte('created_at', firstDay)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10)); // Timeout preventivo

      _historialSolicitudes = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint("Error historial solicitudes: $e");
    }
  }

  // RF-68: Suscripción Realtime para el tablero de solicitudes
  void _initRealtimeSolicitudes() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase.from('asesores_negocio').select('id').eq('user_id', userId).single().then((asesorData) {
      final asesorId = asesorData['id'];
      
      _solicitudesRealtimeSubscription = _supabase
          .from('solicitudes_credito')
          .stream(primaryKey: ['id'])
          .eq('asesor_id', asesorId)
          .listen((List<Map<String, dynamic>> data) {
            _solicitudesTablero = data.map((item) => Map<String, dynamic>.from(item)).toList();
            _solicitudesTablero.sort((a, b) {
              final dateA = a['created_at']?.toString() ?? '';
              final dateB = b['created_at']?.toString() ?? '';
              return dateB.compareTo(dateA);
            });
            notifyListeners();
          });
    }).catchError((e) => debugPrint("Error initRealtimeSolicitudes: $e"));
  }

  // RF-79: Monitor de supervisión en tiempo real
  void initMonitoreoRealtime() {
    _monitoreoSubscription?.cancel();
    _monitoreoSubscription = _supabase
        .from('cartera_diaria') 
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) async {
          // Procesamos el mapa en un isolate para no congelar la UI
          _monitoreoAsesores = await compute(_procesarMonitoreoInIsolate, data);
          notifyListeners();
        });
  }

  static List<Map<String, dynamic>> _procesarMonitoreoInIsolate(List<Map<String, dynamic>> data) {
    final Map<String, Map<String, dynamic>> map = {};
    for (var item in data) {
      final String id = item['asesor_id']?.toString() ?? 'sin_asignar';
      if (!map.containsKey(id)) {
        map[id] = {
          'id': id,
          'nombre': 'Asesor ${id.length >= 5 ? id.substring(0, 5) : id}',
          'total': 0,
          'visitados': 0,
          'lat': item['lat_visita'],
          'lng': item['lng_visita'],
          'ultima_sync': item['updated_at'],
        };
      }
      map[id]!['total']++;
      if (item['estado_visita'] == 'visitado') map[id]!['visitados']++;
      if (item['lat_visita'] != null) {
        map[id]!['lat'] = item['lat_visita'];
        map[id]!['lng'] = item['lng_visita'];
      }
    }
    return map.values.toList();
  }

  // RF-80: Consulta de productividad agregada mensual
  Future<void> fetchProductividadMensual() async {
    _isLoading = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1).toIso8601String();

      // Simulamos agregación que vendría de un RPC o Vista en Supabase
      // En producción: await _supabase.rpc('get_regional_productivity', ...)
      _productividadAsesores = [
        {'nombre': 'Juan Perez', 'enviadas': 18, 'aprobadas': 12, 'desembolsadas': 10, 'monto': 85000},
        {'nombre': 'Maria Lopez', 'enviadas': 14, 'aprobadas': 13, 'desembolsadas': 12, 'monto': 92000},
        {'nombre': 'Carlos Ruiz', 'enviadas': 22, 'aprobadas': 10, 'desembolsadas': 8, 'monto': 64000},
      ];
    } catch (e) {
      debugPrint("Error fetchProductividadMensual: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // HU-23: Verificar si existe una consulta realizada en los últimos 30 días
  Future<Map<String, dynamic>?> verificarConsultaReciente(String clienteId) async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    try {
      final data = await _supabase
          .from('consultas_buro')
          .select()
          .eq('cliente_id', clienteId)
          .gte('fecha_consulta', thirtyDaysAgo)
          .maybeSingle();
      // Retornamos el resultado completo, no solo el sub-campo 'resultado'
      return data;
    } catch (e) {
      return null;
    }
  }

  // RF-58/60: Consulta combinada buró y listas negras (Edge Function)
  Future<void> consultarBuroYListas(String clienteId, String firmaBase64) async {
    _isLoading = true;
    _resultadoBuro = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _supabase.functions.invoke('consulta-buro-listas', body: {
        'cliente_id': clienteId,
        'firma_consentimiento': firmaBase64,
        'timestamp': DateTime.now().toIso8601String(),
      })
      .timeout(const Duration(seconds: 20)); // Timeout para la Edge Function

      if (response.data != null && response.data is Map) {
        _resultadoBuro = Map<String, dynamic>.from(response.data);
      } else {
        debugPrint("Respuesta de buró no es un mapa: ${response.data}");
        _errorMessage = "Respuesta del sistema de riesgos inválida.";
      }
      
      // Registrar auditoría HU-23
      if (_resultadoBuro != null) {
        await _supabase.from('consultas_buro').insert({
        'cliente_id': clienteId,
        'asesor_id': _supabase.auth.currentUser?.id,
        'resultado': _resultadoBuro,
        'fecha_consulta': DateTime.now().toIso8601String(),
      });
      }
    } catch (e) {
      debugPrint("Error consulta buró: $e");
      _errorMessage = "Error al consultar buró: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // RF-75: Consulta de mora diaria
  Future<void> fetchCarteraVencida() async {
    _isLoading = true;
    notifyListeners();
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('cartera_vencida')
          .select('*, clientes(nombres, apellidos)')
          .eq('asesor_id', userId)
          .gt('dias_mora', 0)
          .order('dias_mora', ascending: false);
          // Timeout para la consulta de cartera vencida
          // .timeout(const Duration(seconds: 15)); 
      _carteraVencida = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("Error fetchCarteraVencida: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // RF-77: Registro de acción de cobranza
  Future<bool> registrarGestionCobranza(Map<String, dynamic> gestionData) async {
    _isLoading = true;
    notifyListeners();
    try {
      Position position = await _determinePosition();
      
      final payload = {
        ...gestionData,
        'asesor_id': _supabase.auth.currentUser?.id,
        'lat_gestion': position.latitude,
        'lng_gestion': position.longitude,
        'timestamp_gestion': DateTime.now().toIso8601String(),
      };

      await _supabase.from('gestiones_cobranza').insert(payload);

      // RF-78: Alerta de seguimiento si es compromiso de pago
      if (payload['resultado'] == 'Compromiso de pago' && payload['fecha_compromiso'] != null) {
        _programarAlertaCompromiso(payload);
      }

      await fetchCarteraVencida();
      return true;
    } catch (e) {
      debugPrint("Error registrarGestionCobranza: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _programarAlertaCompromiso(Map<String, dynamic> data) async {
    final scheduledDate = DateTime.parse(data['fecha_compromiso']);
    final scheduledTime = DateTime(scheduledDate.year, scheduledDate.month, scheduledDate.day, 9, 0);
    
    if (scheduledTime.isAfter(DateTime.now())) {
       debugPrint("Alerta programada para seguimiento de cobranza: $scheduledTime");
    }
  }

  // RF-72: Agregar notas internas a una solicitud
  Future<bool> agregarNotaInterna(String solicitudId, String contenido) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase.from('solicitudes_notas_internas').insert({
        'solicitud_id': solicitudId,
        'asesor_id': userId,
        'contenido': contenido,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint("Error agregando nota: $e");
      return false;
    }
  }

  // RF-54: Procesamiento de imagen (Nitidez y Compresión) y subida
  Future<bool> procesarYSubirDocumento(String solicitudId, String tipo, File file) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final bytes = await file.readAsBytes();

      // Mover el procesamiento de imagen a un Isolate para evitar bloqueos de UI
      final Map<String, dynamic> processedImage = await compute(_processImageInIsolate, {
        'bytes': bytes,
        'tipo': tipo,
      });

      if (processedImage['error'] != null) {
        throw Exception(processedImage['error']);
      }
      
      final File compressedFile = processedImage['file'];

      // Subida a Supabase Storage
      final path = 'documentos_solicitudes/$solicitudId/$tipo.jpg';
      await _supabase.storage.from('expedientes').upload(
        path,
        compressedFile,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      ).timeout(const Duration(seconds: 30)); // Timeout para la subida

      _documentosEstado[tipo] = 'LISTO';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error al procesar documento: $e");
      _errorMessage = "Error al procesar o subir documento: ${e.toString()}";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Función top-level para procesamiento de imagen en un Isolate
  static Future<Map<String, dynamic>> _processImageInIsolate(Map<String, dynamic> args) async {
    final Uint8List? bytes = args['bytes'] as Uint8List?;
    final String tipo = args['tipo'];

    if (bytes == null || bytes.isEmpty) {
      return {'error': "Los datos de la imagen están vacíos o son inválidos."};
    }

    img.Image? image = img.decodeImage(bytes);
    if (image == null) return {'error': "No se pudo decodificar la imagen."};

    // Validación de nitidez (proxy: dimensiones mínimas)
    if (image.width < 800 || image.height < 800) { // Reducido un poco el umbral
      return {'error': "La foto no es lo suficientemente nítida o tiene baja resolución."};
    }

    // Compresión iterativa hasta < 800 KB
    int calidad = 90;
    List<int> compressedBytes;
    do {
      compressedBytes = img.encodeJpg(image, quality: calidad);
      calidad -= 10;
    } while (compressedBytes.length > 800 * 1024 && calidad > 10);

    final tempDir = await getTemporaryDirectory();
    final compressedFile = File('${tempDir.path}/temp_$tipo.jpg');
    await compressedFile.writeAsBytes(compressedBytes);

    return {'file': compressedFile};
  }

  // RF-56: Eliminación de documento
  Future<void> eliminarDocumento(String solicitudId, String tipo) async {
    try {
      final path = 'documentos_solicitudes/$solicitudId/$tipo.jpg';
      await _supabase.storage.from('expedientes').remove([path]);
      
      // Restaurar estado según obligatoriedad
      if (tipo == 'recibo_servicios') {
        _documentosEstado[tipo] = 'PENDIENTE';
      } else {
        _documentosEstado[tipo] = 'OBLIGATORIO';
      }
      notifyListeners();
      // Timeout para la eliminación
    } catch (e) {
      debugPrint("Error al eliminar documento: $e");
    }
  }

  // Getter para validar si se puede enviar la solicitud (HU-21)
  bool get puedeEnviarSolicitud {
    return !_documentosEstado.entries
        .any((e) => e.value == 'OBLIGATORIO');
  }

  String getUrlDocumento(String solicitudId, String tipo) {
    return _supabase.storage
        .from('expedientes')
        .getPublicUrl('documentos_solicitudes/$solicitudId/$tipo.jpg');
  }

  // RF-43/HU-17: Envío de solicitud completa
  Future<String?> enviarSolicitud(Map<String, dynamic> solicitudData) async {
    // Flujo 2: Verificación de documentos antes del registro central
    if (!puedeEnviarSolicitud) {
      throw Exception("Faltan documentos obligatorios.");
    }

    _isLoading = true;
    notifyListeners();
    try {
      if (!_isOffline) {
        final response = await _supabase.from('solicitudes_credito').insert(solicitudData).select().single()
            .timeout(const Duration(seconds: 20)); // Timeout para la inserción
        await fetchSolicitudesMes();
        return response['numero_expediente']; // Retorna el folio generado
      } else {
        // Flujo 3: Guardar en cola local si no hay red
        final tempExp = 'PENDIENTE-${DateTime.now().millisecondsSinceEpoch}';
        await _db.saveSolicitudPendiente({
          'id': tempExp,
          'datos_json': jsonEncode(solicitudData),
          'created_at': DateTime.now().toIso8601String()
        });
        _queueSolicitudes = await _db.getSolicitudesPendientes();
        return tempExp;
      }
    } catch (e) {
      debugPrint("Error enviando solicitud: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncPendingSolicitudes() async {
    if (_queueSolicitudes.isEmpty) return;

    for (var solicitud in _queueSolicitudes) {
      try {
        final data = jsonDecode(solicitud['datos_json']);
        await _supabase.from('solicitudes_credito').insert(data);
        await _db.marcarSolicitudSincronizada(solicitud['id']);
      } catch (e) {
        debugPrint("Error sincronizando solicitud: $e");
      }
    }

    _queueSolicitudes = await _db.getSolicitudesPendientes();
    notifyListeners();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    _ultimaActualizacion = prefs.getString('ultima_sincro') ?? "No sincronizado";
    notifyListeners();
  }

  Future<void> _loadManualOrder() async {
    final prefs = await SharedPreferences.getInstance();
    _manualOrderIds = prefs.getStringList('cartera_orden_local') ?? [];
    notifyListeners();
  }

  Future<void> _saveManualOrder() async {
    final prefs = await SharedPreferences.getInstance();
    // Solo guardamos el orden de los IDs de la lista actual (ya filtrada/ordenada)
    await prefs.setStringList('cartera_orden_local', _manualOrderIds);
  }

  // RF-18: Monitor de red para sincronización automática
  void _initConnectivityMonitor() async {
    _queueVisitas = await _db.getVisitasPendientes();
    _queueSolicitudes = await _db.getSolicitudesPendientes();

    final initialConnectivity = await Connectivity().checkConnectivity();
    _isOffline = initialConnectivity.every((r) => r == ConnectivityResult.none);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _isOffline = results.every((r) => r == ConnectivityResult.none);
      if (!_isOffline) {
        _syncPendingVisits();
        _syncPendingSolicitudes();
      }
      notifyListeners();
    });
  }

  // RF-35: Suscripción Realtime para alertas de cartera
  void _initRealtimeAlerts() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _realtimeSubscription = _supabase
        .from('alertas_cartera')
        .stream(primaryKey: ['id'])
        .eq('asesor_id', userId)
        .listen((List<Map<String, dynamic>> data) {
          _alertasNoLeidas = data.where((a) => a['leida'] == false).length;
          notifyListeners();
        });
  }

  // RF-40: Consulta de campañas activas (Renovaciones/Ampliaciones)
  Future<void> fetchCampanas() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final today = DateTime.now().toIso8601String();
      final data = await _supabase
          .from('campanas_activas')
          .select('*, clientes(nombres, apellidos)')
          .eq('asesor_id', userId)
          .eq('activa', true)
          .gte('fecha_vencimiento', today)
          .order('fecha_vencimiento', ascending: true)
          .timeout(const Duration(seconds: 10)); // Timeout para campañas

      _campanasActivas = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint("Error cargando campañas: $e");
    }
  }

  // RF-38: Consulta en línea al sistema de pre-evaluación
  Future<void> preEvaluarProspecto(Map<String, dynamic> prospectoData) async {
    _isLoading = true;
    _resultadoPreEvaluacion = null;
    notifyListeners();

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.any((r) => r != ConnectivityResult.none)) {
        // Invocación a Edge Function
        final response = await _supabase.functions.invoke(
          'pre-evaluar',
          body: prospectoData,
        ).timeout(const Duration(seconds: 20)); // Timeout para pre-evaluación
        _resultadoPreEvaluacion = response.data;
      } else {
        // Modo Offline: Guardar en cola para procesar después
        await _enqueueVisita({...prospectoData, 'tipo_tarea': 'prospeccion'});
        _resultadoPreEvaluacion = {
          'calificacion': 'PENDIENTE',
          'motivo': 'Sin conexión. Se procesará al reconectar.'
        };
      }
    } catch (e) {
      debugPrint("Error en pre-evaluación: $e");
      _resultadoPreEvaluacion = {
        'calificacion': 'ERROR',
        'motivo': 'Error de comunicación con el sistema de scoring.'
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // RF-42: Registro de cliente desertor
  Future<void> registrarDesertor(String clienteId, Map<String, dynamic> desertorData) async {
    try {
      await _supabase.from('clientes').update({
        'estado': 'Terminada',
        'tipo_gestion': 'DESERTOR',
        'datos_desercion': desertorData,
        'visitado': true,
      }).eq('id', clienteId)
      .timeout(const Duration(seconds: 10)); // Timeout para actualizar cliente
      
      await fetchClientes(); // Refrescar lista
    } catch (e) {
      debugPrint("Error al registrar desertor: $e");
    }
  }

  // HU-11: Carga de datos extendidos de la ficha
  Future<void> fetchDetalleCliente(String clienteId) async {
    _isLoading = true;
    _posicionConsolidada = null;
    _historialCreditos = [];
    _ofertaPreaprobada = null;
    _resultadoBuro = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // RF-30: Invocación de Edge Function para posición consolidada
      final response = await _supabase.functions.invoke('consulta-posicion', body: {'cliente_id': clienteId});
      _posicionConsolidada = response.data; // Timeout para la Edge Function
      // .timeout(const Duration(seconds: 20));

      // RF-33: Consulta de preaprobados vigentes
      final ofertaData = await _supabase
          .from('creditos_preaprobados')
          .select()
          .eq('cliente_id', clienteId)
          .eq('vigente', true)
          .gte('fecha_vencimiento', DateTime.now().toIso8601String())
          .order('score_confianza', ascending: false)
          .maybeSingle();
      _ofertaPreaprobada = ofertaData; // Timeout para la consulta
      // .timeout(const Duration(seconds: 10));

      // Consulta de historial
      final historialData = await _supabase
          .from('historial_creditos')
          .select()
          .eq('cliente_id', clienteId)
          .order('fecha_desembolso', ascending: false)
          .limit(5);
      _historialCreditos = List<Map<String, dynamic>>.from(historialData); // Timeout para la consulta
      // .timeout(const Duration(seconds: 10));

    } catch (e) {
      debugPrint("Error cargando detalle: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // RF-32: Cálculo de indicadores de comportamiento
  Map<String, dynamic> get indicadoresComportamiento {
    if (_historialCreditos.isEmpty) return {'puntualidad': 0.0, 'moraPromedio': 0.0, 'totalPagado': 0.0};
    
    double totalPagado = 0;
    int totalCuotas = 0;
    int cuotasPuntuales = 0;
    int cuotasMorosas = 0;
    int sumaDiasMora = 0;

    // Nota: Aquí se procesarían los datos de movimientos detallados descargados
    return {
      'puntualidad': 85.0, // Mock de lógica RF-32
      'moraPromedio': 2.5,
      'totalPagado': 15400.0,
    };
  }

  /// RF-17: Registro de resultado de visita con GPS y modo offline
  Future<bool> registrarVisita(String clienteId, String resultado, String observacion) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Captura de GPS
      Position position = await _determinePosition();

      // HU-09: RF-24 - Detección de visita fuera de zona
      bool estaEnZona = _isPointInPolygon(LatLng(position.latitude, position.longitude), _geocercaPuntos);
      
      final visitaData = {
        'estado_visita': 'visitado',
        'resultado_visita': resultado,
        'observacion_visita': observacion,
        'timestamp_visita': DateTime.now().toIso8601String(),
        'lat_visita': position.latitude,
        'lng_visita': position.longitude,
      };

      final connectivity = await Connectivity().checkConnectivity();
      bool hasNet = connectivity.any((r) => r != ConnectivityResult.none);

      if (hasNet) {
        // Intentar envío a Supabase
        await _supabase.from('cartera_diaria').update(visitaData).eq('id', clienteId)
            .timeout(const Duration(seconds: 15)); // Timeout para la actualización
      } else {
        // Sin conexión: Guardar en cola local
        await _enqueueVisita({
          'id': clienteId,
          ...visitaData
        });
      }

      // Actualizar estado local para feedback inmediato en UI
      final idx = _clientes.indexWhere((c) => c.id == clienteId);
      if (idx != -1) {
        _clientes[idx] = _clientes[idx].copyWith(estado: 'Terminada', visitado: true);
      }
      
      return true; 
    } catch (e) {
      debugPrint("Error registrando visita: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _enqueueVisita(Map<String, dynamic> data) async {
    final localItem = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'cartero_id': data['id'],
      'resultado': data['resultado_visita'],
      'observacion': data['observacion_visita'],
      'timestamp_visita': data['timestamp_visita'],
      'lat': data['lat_visita'],
      'lng': data['lng_visita'],
      'pendiente_sync': 1
    };
    await _db.saveVisitaPendiente(localItem);
    _queueVisitas = await _db.getVisitasPendientes();
    notifyListeners();
  }

  Future<void> _syncPendingVisits() async {
    if (_queueVisitas.isEmpty) return;

    for (var visita in _queueVisitas) {
      try {
        await _supabase.from('clientes').update({
          'estado_visita': 'visitado',
          'resultado_visita': visita['resultado'],
          'observacion_visita': visita['observacion'],
          'timestamp_visita': visita['timestamp_visita'],
          'lat_visita': visita['lat'],
          'lng_visita': visita['lng'],
        }).eq('id', visita['cartero_id']);
        // Timeout para la actualización
        // .timeout(const Duration(seconds: 15));
        await _db.marcarSincronizada(visita['id']);
      } catch (e) {
        debugPrint("Error sincronizando registro ${visita['id']}: $e");
      }
    }

    _queueVisitas = await _db.getVisitasPendientes();
    notifyListeners();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Servicios de ubicación desactivados.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Permiso denegado.');
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // HU-08: RF-21 - Algoritmo del Vecino más cercano
  Future<void> optimizarRuta() async {
    _isLoading = true;
    _errorMessage = null; // Limpiar errores previos
    notifyListeners();
    
    try {
      Position currentPos = await _determinePosition();
      List<Cliente> pendientes = _clientes.where((c) => !c.visitado && c.latitud != null && c.longitud != null).toList();

      if (pendientes.isEmpty) {
        _rutaOptimizada = [];
        return; // No hay nada que optimizar
      }

      // Mover la lógica de optimización a un Isolate
      final List<Cliente> optimizada = await compute(_optimizeRouteInIsolate, {
        'currentLat': currentPos.latitude,
        'currentLng': currentPos.longitude,
        'pendientes': pendientes,
      });

      _rutaOptimizada = optimizada;
      // También actualizamos el orden manual para que la lista de cartera coincida
      _manualOrderIds = optimizada.map((c) => c.id).toList();
      await _saveManualOrder();
    } catch (e) {
      debugPrint("Error optimizando ruta: $e");
      _errorMessage = "Error al optimizar ruta: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Función top-level para optimización de ruta en un Isolate
  static List<Cliente> _optimizeRouteInIsolate(Map<String, dynamic> args) {
    double currentLat = args['currentLat'];
    double currentLng = args['currentLng'];
    List<Cliente> pendientes = List<Cliente>.from(args['pendientes']);
    List<Cliente> optimizada = [];

    while (pendientes.isNotEmpty) {
      Cliente proximo = pendientes.first;
      double minDist = double.maxFinite;
      int proximoIdx = 0;

      for (int i = 0; i < pendientes.length; i++) {
        double dist = Geolocator.distanceBetween(currentLat, currentLng, pendientes[i].latitud!, pendientes[i].longitud!);
        if (dist < minDist) { minDist = dist; proximo = pendientes[i]; proximoIdx = i; }
      }
      optimizada.add(proximo); currentLat = proximo.latitud!; currentLng = proximo.longitud!;
      pendientes.removeAt(proximoIdx);
    }
    return optimizada;
  }

  // HU-10: RF-25/26 - Captura de ubicación del negocio y geocodificación inversa
  Future<String?> capturarUbicacionNegocio(String clienteId) async {
    try {
      Position pos = await _determinePosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String direccion = "${place.street}, ${place.locality}, ${place.subAdministrativeArea}";
        
        // Actualizar en Supabase
        await _supabase.from('clientes').update({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'direccion': direccion
        }).eq('id', clienteId)
        .timeout(const Duration(seconds: 10)); // Timeout para la actualización

        // Actualizar localmente
        final idx = _clientes.indexWhere((c) => c.id == clienteId);
        if (idx != -1) {
          _clientes[idx] = _clientes[idx].copyWith(latitud: pos.latitude, longitud: pos.longitude);
        }
        notifyListeners();
        return direccion;
      } else {
        debugPrint("No se encontraron resultados de geocodificación.");
      }
    } catch (e) {
      debugPrint("Error en geocodificación: $e");
    }
    return null;
  }

  // HU-08: RF-22 - Lanzar navegación externa (Waze > Google Maps)
  Future<void> lanzarNavegacion(double lat, double lng) async {
    final wazeUrl = Uri.parse("waze://?ll=$lat,$lng&navigate=yes");
    final googleUrl = Uri.parse("google.navigation:q=$lat,$lng");
    
    if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl);
    } else if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl);
    } else {
      await launchUrl(Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng"));
    }
  }

  // RF-24: Algoritmo Ray Casting (Point in Polygon)
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty) return true; // Si no hay geocerca definida, asumimos que está en zona
    int intersectCount = 0;
    for (int j = 0; j < polygon.length; j++) {
      LatLng vert1 = polygon[j];
      LatLng vert2 = polygon[(j + 1) % polygon.length];
      if ((vert1.latitude > point.latitude) != (vert2.latitude > point.latitude) &&
          (point.longitude < (vert2.longitude - vert1.longitude) * (point.latitude - vert1.latitude) /
              (vert2.latitude - vert1.latitude) + vert1.longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount % 2) == 1;
  }

  /// Carga los clientes asignados al oficial actual desde Supabase
  Future<void> fetchClientes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Obtenemos el ID del asesor desde la tabla asesores_negocio para filtrar la cartera
      final asesorData = await _supabase
          .from('asesores_negocio')
          .select('id, perfil')
          .eq('user_id', userId)
          .single();
      final asesorId = asesorData['id'];
      final perfil = (asesorData['perfil'] ?? 'operador').toString().toLowerCase();
      
      debugPrint('CarteraViewModel: Cargando cartera para $perfil ($asesorId)');

      // RF-09: Consulta a tabla cartera_diaria con filtros de fecha actual
      final today = DateTime.now().toIso8601String().split('T')[0];
      var query = _supabase.from('cartera_diaria').select('*, clientes(*), asesores_negocio(nombres, apellidos)');

      // HU-02: Filtro por asesor solo para Operadores. 
      // Administradores y Supervisores ven la cartera de toda la agencia.
      if (perfil == 'operador' || perfil == 'super_operador') {
        query = query.eq('asesor_id', asesorId);
      }

      final data = await query
          .eq('fecha_asignacion', today)
          .order('score_prioridad', ascending: false)
          .timeout(const Duration(seconds: 20)); // Timeout para la consulta principal
          
      debugPrint('CarteraViewModel: Registros recibidos: ${(data as List).length}');

      // Procesamos el mapeo en un Isolate para no bloquear la UI
      _clientes = await compute(_parseClientesInIsolate, List<dynamic>.from(data as Iterable));
      
      // HU-05: Registrar marca de tiempo de actualización
      final now = DateTime.now();
      _ultimaActualizacion = "hoy ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ultima_sincro', _ultimaActualizacion);
    } catch (e) {
      debugPrint('Error al cargar cartera: $e');
      _errorMessage = "Error al cargar cartera: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static List<Cliente> _parseClientesInIsolate(List<dynamic> data) {
    return data.map((item) {
      if (item == null) return null;
      
      final Map<String, dynamic> flattened = Map<String, dynamic>.from(item as Map);
      if (item['clientes'] != null && item['clientes'] is Map) {
        // Unimos los datos de la tarea con los datos maestros del cliente
        flattened.addAll(Map<String, dynamic>.from(item['clientes']));
      }
      // Capturamos el nombre del asesor para la gestión de reasignación (Supervisor/Admin)
      if (item['asesores_negocio'] != null && item['asesores_negocio'] is Map) {
        final a = item['asesores_negocio'];
        flattened['nombre_asesor'] = "${a['nombres'] ?? ''} ${a['apellidos'] ?? ''}".trim();
      }
      return Cliente.fromJson(flattened);
    }).whereType<Cliente>().toList();
  }

  /// Cambia el filtro de la lista (Todas, En Ruta, Terminadas)
  void setFiltro(String nuevoFiltro) {
    _filtroActual = nuevoFiltro;
    notifyListeners();
  }

  /// RF-16: Reordenamiento manual con arrastrar y soltar
  void reorderClientes(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final List<Cliente> list = clientes; // Obtenemos la lista actual filtrada
    final Cliente movedItem = list.removeAt(oldIndex);
    list.insert(newIndex, movedItem);

    // Actualizamos el mapa de IDs para persistir el orden local
    _manualOrderIds = list.map((c) => c.id).toList();
    _saveManualOrder();
    notifyListeners();
  }

  /// RF-12: Búsqueda con delay de 300ms
  void setSearchQuery(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchQuery = query;
      notifyListeners();
    });
  }

  /// RF-07: Borra los datos de la cartera en caché local
  void clearLocalData() {
    _clientes = [];
    _filtroActual = 'Todos';
    notifyListeners();
  }

  // RF-29: Llamada directa
  Future<void> lanzarLlamada(String numero) async {
    final Uri url = Uri.parse("tel:$numero");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _realtimeSubscription?.cancel();
    _solicitudesRealtimeSubscription?.cancel();
    _monitoreoSubscription?.cancel();
    super.dispose();
  }
}