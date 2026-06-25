class Cliente {
  final String id; // Folio o Código
  final String clienteId;
  final String nombres;
  final String apellidos;
  final String? fechaNacimiento;
  final String? estadoCivil;
  final String tipoGestion; 
  final String estado; // Pendiente, En Ruta, Terminada
  final String? oficialId;
  final String? nombreAsesor;
  final String tipoDocumento;
  final String numeroDocumento;
  final double monto;
  final double? ingresosEstimados;
  final int? antiguedadNegocioMeses;
  final String? nombreNegocio;
  final String prioridad; // ALTA, MEDIA, NORMAL
  final int scorePrioridad;
  final bool visitado;
  final int? diasMora;
  final double? latitud;
  final double? longitud;
  final String? telefono;
  final String? direccion;
  final String? negocioTipo;
  final String? negocioAntiguedad;
  final String calificacionSBS; // Normal, CPP, Deficiente, Dudoso, Perdida

  Cliente({
    required this.id,
    required this.clienteId,
    required this.nombres,
    required this.apellidos,
    this.fechaNacimiento,
    this.estadoCivil,
    required this.tipoGestion,
    required this.estado,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.monto,
    this.ingresosEstimados,
    this.antiguedadNegocioMeses,
    this.nombreNegocio,
    required this.prioridad,
    required this.scorePrioridad,
    this.oficialId,
    this.nombreAsesor,
    this.visitado = false,
    this.diasMora,
    this.latitud,
    this.longitud,
    this.telefono,
    this.direccion,
    this.negocioTipo,
    this.negocioAntiguedad,
    this.calificacionSBS = 'Normal',
  });

  String get nombreCompleto => "$nombres $apellidos";

  /// RF-15: Lógica de puntaje de prioridad calculado localmente
  static int calcularScoreLocal(Map<String, dynamic> json) {
    if (json['score_prioridad'] != null) return json['score_prioridad'];

    int score = 0;
    final tipo = (json['tipo_gestion'] ?? '').toString().toUpperCase();
    final montoValue = (json['monto'] ?? 0).toDouble();
    final dias = json['dias_mora'] ?? 0;

    if (tipo == 'RECUPERACION MORA') {
      score += 40;
      score += (dias as int).clamp(0, 30);
    } else if (tipo == 'RENOVACION' && montoValue > 5000) {
      score += 35;
    } else if (tipo == 'AMPLIACION') {
      score += 25;
    } else if (tipo == 'SEGUIMIENTO') {
      score += 10;
    } else if (tipo == 'NUEVA SOLICITUD') {
      score += 5;
    }
    return score.clamp(0, 100);
  }

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      nombres: json['nombres'] ?? '',
      apellidos: json['apellidos'] ?? '',
      fechaNacimiento: json['fecha_nacimiento'],
      estadoCivil: json['estado_civil'],
      tipoGestion: json['tipo_gestion'] ?? '',
      estado: json['estado_visita'] ?? (json['estado'] ?? 'pendiente'),
      tipoDocumento: json['tipo_documento'] ?? 'DNI',
      numeroDocumento: json['numero_documento'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      ingresosEstimados: (json['ingresos_estimados'] ?? 0).toDouble(),
      antiguedadNegocioMeses: json['antiguedad_negocio_meses'],
      nombreNegocio: json['nombre_negocio'],
      prioridad: json['prioridad'] ?? 'NORMAL',
      scorePrioridad: calcularScoreLocal(json),
      oficialId: json['asesor_id'],
      nombreAsesor: json['nombre_asesor'],
      visitado: json['estado_visita']?.toString().toLowerCase() == 'visitado',
      diasMora: json['dias_mora'],
      latitud: (json['lat'] as num?)?.toDouble() ?? (json['latitud'] as num?)?.toDouble(),
      longitud: (json['lng'] as num?)?.toDouble() ?? (json['longitud'] as num?)?.toDouble(),
      telefono: json['telefono']?.toString(),
      direccion: json['direccion']?.toString(),
      negocioTipo: json['tipo_negocio']?.toString(),
      negocioAntiguedad: json['negocio_antiguedad']?.toString(),
      calificacionSBS: json['calificacion_sbs'] ?? 'Normal',
    );
  }

  String get documentoCensurado {
    if (numeroDocumento.length < 3) return "***";
    return "***${numeroDocumento.substring(numeroDocumento.length - 3)}";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nacimiento': fechaNacimiento,
      'estado_civil': estadoCivil,
      'tipo_gestion': tipoGestion,
      'estado': estado,
      'tipo_documento': tipoDocumento,
      'numero_documento': numeroDocumento,
      'monto': monto,
      'ingresos_estimados': ingresosEstimados,
      'antiguedad_negocio_meses': antiguedadNegocioMeses,
      'nombre_negocio': nombreNegocio,
      'prioridad': prioridad,
      'asesor_id': oficialId,
      'nombre_asesor': nombreAsesor,
      'dias_mora': diasMora,
      'lat': latitud,
      'lng': longitud,
      'telefono': telefono,
      'direccion': direccion,
      'tipo_negocio': negocioTipo,
      'negocio_antiguedad': negocioAntiguedad,
      'calificacion_sbs': calificacionSBS,
    };
  }

  Cliente copyWith({
    String? estado,
    bool? visitado,
    double? latitud,
    double? longitud,
    String? nombreAsesor,
  }) {
    return Cliente(
      id: id,
      clienteId: clienteId,
      nombres: nombres,
      apellidos: apellidos,
      tipoGestion: tipoGestion,
      estado: estado ?? this.estado,
      tipoDocumento: tipoDocumento,
      numeroDocumento: numeroDocumento,
      monto: monto,
      prioridad: prioridad,
      scorePrioridad: scorePrioridad,
      oficialId: oficialId,
      nombreAsesor: nombreAsesor ?? this.nombreAsesor,
      visitado: visitado ?? this.visitado,
      diasMora: diasMora,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
    );
  }
}