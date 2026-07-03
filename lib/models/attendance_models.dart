/// Modelo de datos que representa el registro de asistencia individual de un estudiante.
class AttendanceRecord {
  final String id;
  final String? estudianteNombre;
  final String? estudianteCodigo;
  final double confidenceScore;
  final String? faceCropUrl;
  final Map<String, dynamic>? boundingBox; // {"x":, "y":, "w":, "h":} en píxeles de la panorámica original
  final String status;
  final bool verificado;

  AttendanceRecord({
    required this.id,
    this.estudianteNombre,
    this.estudianteCodigo,
    required this.confidenceScore,
    this.faceCropUrl,
    this.boundingBox,
    required this.status,
    required this.verificado,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id']?.toString() ?? '',
      estudianteNombre: json['estudiante_nombre'] as String?,
      estudianteCodigo: json['estudiante_codigo'] as String?,
      confidenceScore: _toDouble(json['confidence_score']),
      faceCropUrl: json['face_crop_url'] as String?,
      boundingBox: json['bounding_box'] as Map<String, dynamic>?,
      status: json['status']?.toString() ?? 'absent',
      verificado: json['verificado'] as bool? ?? false,
    );
  }

  /// Helper estático para garantizar la conversión segura a double sin importar si viene int o double.
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}

/// Modelo de datos que consolida los resultados globales y métricas de una sesión biométrica.
class SessionResults {
  final String id;
  final String fechaSesion;
  final String seccionCodigo;
  final String cursoNombre;
  final String statusProceso;
  final String? panoramaUrl;
  final int totalInscritos;
  final int totalDetectados;
  final int totalReconocidos;
  final int totalAusentes;
  final double porcentajeAsistencia;
  final List<AttendanceRecord> records;

  SessionResults({
    required this.id,
    required this.fechaSesion,
    required this.seccionCodigo,
    required this.cursoNombre,
    required this.statusProceso,
    required this.panoramaUrl,
    required this.totalInscritos,
    required this.totalDetectados,
    required this.totalReconocidos,
    required this.totalAusentes,
    required this.porcentajeAsistencia,
    required this.records,
  });

  /// Factory para construir una instancia segura a partir de un mapa JSON.
  factory SessionResults.fromJson(Map<String, dynamic> json) {
    // Procesa la lista interna de registros controlando nulos de manera segura
    final rawRecords = json['records'] as List<dynamic>? ?? [];
    final parsedRecords = rawRecords
        .map((item) => AttendanceRecord.fromJson(item as Map<String, dynamic>))
        .toList();

    return SessionResults(
      id: json['id']?.toString() ?? '',
      fechaSesion: json['fecha_sesion']?.toString() ?? '',
      seccionCodigo: json['seccion_codigo']?.toString() ?? '',
      cursoNombre: json['curso_nombre']?.toString() ?? '',
      statusProceso: json['status_proceso']?.toString() ?? '',
      panoramaUrl: json['panorama_url'] as String?,
      totalInscritos: _toInt(json['total_inscritos']),
      totalDetectados: _toInt(json['total_detectados']),
      totalReconocidos: _toInt(json['total_reconocidos']),
      totalAusentes: _toInt(json['total_ausentes']),
      porcentajeAsistencia: AttendanceRecord._toDouble(json['porcentaje_asistencia']),
      records: parsedRecords,
    );
  }

  /// Helper estático para garantizar la conversión segura a int sin romper por variaciones de tipos.
  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}