import 'dart:io';
import 'package:dio/dio.dart';
import '../models/attendance_models.dart';

/// Excepción específica para cuando el backend responde 409 al crear una
/// sesión porque ya existe una para esa sección en esa fecha.
class SessionAlreadyExistsException implements Exception {
  final String message;
  SessionAlreadyExistsException(this.message);
  @override
  String toString() => message;
}

/// Servicio centralizado de red encargado de todas las peticiones HTTP de la app.
/// Implementa el patrón Singleton para asegurar una única instancia de Dio global.
class ApiService {
  // Configuración de red local (10.0.2.2 mapea a localhost desde el emulador Android)
  static const String _baseUrl = 'http://192.168.0.10:8000';
  static String get baseUrl => _baseUrl;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    contentType: Headers.jsonContentType,
    headers: {
      'ngrok-skip-browser-warning': 'true',
    },
  ));

  // --- SINGLETON PATTERN ---
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- ESTADO GLOBAL DE AUTENTICACIÓN ---
  String? _token;
  String? get token => _token;

  String? _nombreUsuario;
  String? get nombreUsuario => _nombreUsuario;

  String? _correoUsuario;
  String? get correoUsuario => _correoUsuario;

  /// Modifica el estado del token y actualiza dinámicamente las cabeceras de Dio.
  void setToken(String? token) {
    _token = token;
    if (token != null && token.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  /// Limpia por completo las credenciales locales de la sesión activa.
  void logout() {
    setToken(null);
    _nombreUsuario = null;
    _correoUsuario = null;
  }

  // --- ENDPOINTS DE AUTENTICACIÓN ---

  /// Realiza la autenticación del usuario.
  /// Mapea a: POST /auth/login
  Future<Map<String, dynamic>> login({
    required String correo,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'correo': correo,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Guardamos el token y los datos del perfil de manera global
        setToken(data['access_token']);
        _nombreUsuario = data['nombre'] ?? 'Usuario';
        _correoUsuario = correo;

        return {
          'success': true,
          'rol': data['rol'],
          'nombre': _nombreUsuario,
        };
      }
      return {'success': false, 'message': 'Respuesta inesperada del servidor.'};
    } on DioException catch (e) {
      return {'success': false, 'message': _manejarErrorDio(e)};
    }
  }

  // --- ENDPOINTS DEL PROFESOR ---

  /// Obtiene la lista de secciones asignadas al profesor autenticado.
  /// Mapea a: GET /sections/
  Future<List<Map<String, dynamic>>> getSections() async {
    try {
      final response = await _dio.get('/sections/');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      throw Exception('Código de estado inesperado: ${response.statusCode}');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Crea una nueva sesión de asistencia para una sección (paso 1 del flujo).
  /// Mapea a: POST /sessions/
  /// [fechaSesion] debe tener formato 'YYYY-MM-DD'.
  Future<Map<String, dynamic>> createSession({
    required String idSeccion,
    required String fechaSesion,
  }) async {
    try {
      final response = await _dio.post(
        '/sessions/',
        data: {
          'id_seccion': idSeccion,
          'fecha_sesion': fechaSesion,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo crear la sesión (código ${response.statusCode}).');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw SessionAlreadyExistsException(_manejarErrorDio(e));
      }
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Sube la foto panorámica de una sesión ya creada (paso 2 del flujo).
  /// Dispara el procesamiento biométrico en segundo plano en el backend.
  /// Mapea a: POST /sessions/{session_id}/upload
  Future<void> uploadPanorama({
    required String sessionId,
    required File imagen,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagen.path,
          filename: 'panorama_asistencia.jpg',
        ),
      });
      final response = await _dio.post(
        '/sessions/$sessionId/upload',
        data: formData,
      );
      if (response.statusCode != 202 && response.statusCode != 200) {
        throw Exception('No se pudo subir la imagen panorámica (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Consulta el estado del procesamiento biométrico de una sesión.
  /// Mapea a: GET /sessions/{session_id}/status
  Future<Map<String, dynamic>> getSessionStatus(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/status');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo consultar el estado de la sesión.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Obtiene el historial de sesiones de una sección específica.
  /// Mapea a: GET /sessions/section/{section_id}
  Future<List<Map<String, dynamic>>> getSectionHistory(String sectionId) async {
    try {
      final response = await _dio.get('/sessions/section/$sectionId');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      throw Exception('No se pudo obtener el historial de la sección.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Anula (soft-delete) una sesión existente, liberando esa fecha para
  /// que se pueda crear una nueva sesión en la misma sección.
  /// Mapea a: PATCH /sessions/{session_id}/anular
  Future<Map<String, dynamic>> annulSession(String sessionId) async {
    try {
      final response = await _dio.patch('/sessions/$sessionId/anular');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo anular la sesión (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Obtiene los resultados del procesamiento biométrico de una sesión.
  /// Mapea a: GET /sessions/{session_id}/results
  Future<SessionResults> getSessionResults(String sessionId) async {
    try {
      final response = await _dio.get('/sessions/$sessionId/results');
      if (response.statusCode == 200) {
        return SessionResults.fromJson(response.data);
      }
      throw Exception('No se pudieron recuperar los resultados de la sesión.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Actualiza o verifica manualmente el registro de asistencia de un estudiante.
  /// Mapea a: PATCH /sessions/{session_id}/results/{record_id}
  Future<AttendanceRecord> verifyAttendanceRecord({
    required String sessionId,
    required String recordId,
    required String status,
  }) async {
    try {
      final response = await _dio.patch(
        '/sessions/$sessionId/results/$recordId',
        data: {
          'id_estudiante': null,
          'status': status,
          'verificado': true,
        },
      );

      if (response.statusCode == 200) {
        return AttendanceRecord.fromJson(response.data);
      }
      throw Exception('Fallo al actualizar el registro en el servidor.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ENDPOINTS DEL ADMIN: ESTUDIANTES ---

  /// Lista el catálogo global de estudiantes de la facultad.
  /// Mapea a: GET /students/
  Future<List<Map<String, dynamic>>> getStudents() async {
    try {
      final response = await _dio.get('/students/');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      throw Exception('No se pudieron obtener los estudiantes.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Crea un nuevo estudiante en el catálogo global.
  /// Mapea a: POST /students/
  Future<Map<String, dynamic>> createStudent({
    required String codigoEstudiante,
    required String nombreCompleto,
  }) async {
    try {
      final response = await _dio.post('/students/', data: {
        'codigo_estudiante': codigoEstudiante,
        'nombre_completo': nombreCompleto,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo crear el estudiante (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ENDPOINTS DEL ADMIN: INSCRIPCIONES (por sección) ---

  /// Lista los estudiantes inscritos en una sección.
  /// Mapea a: GET /sections/{section_id}/students
  Future<List<Map<String, dynamic>>> getEnrolledStudents(String sectionId) async {
    try {
      final response = await _dio.get('/sections/$sectionId/students');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      throw Exception('No se pudo obtener la lista de inscritos.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Inscribe a un estudiante en una sección.
  /// Mapea a: POST /sections/{section_id}/enroll
  Future<void> enrollStudent({required String sectionId, required String studentId}) async {
    try {
      final response = await _dio.post(
        '/sections/$sectionId/enroll',
        data: {'id_estudiante': studentId},
      );
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('No se pudo inscribir al estudiante (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Retira a un estudiante de una sección.
  /// Mapea a: DELETE /sections/{section_id}/enroll/{student_id}
  Future<void> unenrollStudent({required String sectionId, required String studentId}) async {
    try {
      final response = await _dio.delete('/sections/$sectionId/enroll/$studentId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('No se pudo retirar al estudiante (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ENDPOINTS DEL ADMIN: EMBEDDINGS (conteo) ---

  /// Devuelve el total de embeddings faciales registrados para un estudiante.
  /// Mapea a: GET /embeddings/{student_id}
  /// Si el estudiante nunca subió fotos, el backend puede responder 404;
  /// en ese caso interpretamos el total como 0 en vez de propagar el error.
  Future<int> getEmbeddingsCount(String studentId) async {
    try {
      final response = await _dio.get('/embeddings/$studentId');
      if (response.statusCode == 200) {
        return (response.data['total'] ?? 0) as int;
      }
      return 0;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return 0;
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Obtiene el detalle completo de embeddings de un estudiante (lista + total).
  /// Mapea a: GET /embeddings/{student_id}
  /// Si el estudiante nunca subió fotos, el backend responde 404; en ese caso
  /// devolvemos una lista vacía en vez de propagar el error.
  Future<List<Map<String, dynamic>>> getEmbeddings(String studentId) async {
    try {
      final response = await _dio.get('/embeddings/$studentId');
      if (response.statusCode == 200) {
        final data = response.data as Map;
        return List<Map<String, dynamic>>.from(data['embeddings'] as List? ?? []);
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Registra un embedding facial a partir de una foto. Se llama una vez por
  /// cada foto que el admin seleccione (el backend procesa una imagen a la vez).
  /// Mapea a: POST /embeddings/{student_id}
  Future<Map<String, dynamic>> registerEmbedding({
    required String studentId,
    required File imagen,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagen.path, filename: 'embedding.jpg'),
      });
      final response = await _dio.post('/embeddings/$studentId', data: formData);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo registrar el embedding (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Elimina un embedding específico.
  /// Mapea a: DELETE /embeddings/{embedding_id}
  Future<void> deleteEmbedding(String embeddingId) async {
    try {
      final response = await _dio.delete('/embeddings/$embeddingId');
      if (response.statusCode != 200) {
        throw Exception('No se pudo eliminar el embedding (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ENDPOINTS DEL ADMIN: USUARIOS ---

  /// Lista usuarios, opcionalmente filtrados por rol (ej. "teacher").
  /// Mapea a: GET /users/?rol=...
  Future<List<Map<String, dynamic>>> getUsers({String? rol}) async {
    try {
      final response = await _dio.get(
        '/users/',
        queryParameters: rol != null ? {'rol': rol} : null,
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      throw Exception('No se pudieron obtener los usuarios.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ENDPOINTS DEL ADMIN: SECCIONES ---

  /// Crea una nueva sección. [idProfesor] es obligatorio cuando quien crea
  /// es un admin (el backend lo exige). [horaInicio]/[horaFin] en formato 'HH:MM'.
  /// Mapea a: POST /sections/
  Future<Map<String, dynamic>> createSection({
    required String idCurso,
    required String idProfesor,
    required String codigoSeccion,
    required int diaSemana,
    required String horaInicio,
    required String horaFin,
    String? aula,
  }) async {
    try {
      final response = await _dio.post('/sections/', data: {
        'id_curso': idCurso,
        'id_profesor': idProfesor,
        'codigo_seccion': codigoSeccion,
        'dia_semana': diaSemana,
        'hora_inicio': '$horaInicio:00',
        'hora_fin': '$horaFin:00',
        'aula': aula,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo crear la sección (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Actualiza una sección existente. No permite cambiar el curso (id_curso)
  /// ni el profesor: el backend no lo soporta en PATCH /sections/{id}.
  Future<Map<String, dynamic>> updateSection({
    required String sectionId,
    String? codigoSeccion,
    int? diaSemana,
    String? horaInicio,
    String? horaFin,
    String? aula,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (codigoSeccion != null) data['codigo_seccion'] = codigoSeccion;
      if (diaSemana != null) data['dia_semana'] = diaSemana;
      if (horaInicio != null) data['hora_inicio'] = '$horaInicio:00';
      if (horaFin != null) data['hora_fin'] = '$horaFin:00';
      if (aula != null) data['aula'] = aula;

      final response = await _dio.patch('/sections/$sectionId', data: data);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo actualizar la sección (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Elimina una sección.
  /// Mapea a: DELETE /sections/{section_id}
  Future<void> deleteSection(String sectionId) async {
    try {
      final response = await _dio.delete('/sections/$sectionId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('No se pudo eliminar la sección (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }


  // --- ENDPOINTS DEL ADMIN: CURSOS ---

  /// Lista todos los cursos del catálogo.
  /// Mapea a: GET /courses/
  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await _dio.get('/courses/');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data as List);
      }
      throw Exception('No se pudieron obtener los cursos.');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Crea un nuevo curso en el catálogo.
  /// Mapea a: POST /courses/
  Future<Map<String, dynamic>> createCourse({
    required String nombreCurso,
    required String codigoCurso,
  }) async {
    try {
      final response = await _dio.post('/courses/', data: {
        'nombre_curso': nombreCurso,
        'codigo_curso': codigoCurso,
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo crear el curso (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Actualiza el nombre y/o código de un curso existente.
  /// Mapea a: PATCH /courses/{course_id}
  Future<Map<String, dynamic>> updateCourse({
    required String courseId,
    String? nombreCurso,
    String? codigoCurso,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nombreCurso != null) data['nombre_curso'] = nombreCurso;
      if (codigoCurso != null) data['codigo_curso'] = codigoCurso;

      final response = await _dio.patch('/courses/$courseId', data: data);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('No se pudo actualizar el curso (código ${response.statusCode}).');
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  /// Elimina un curso del catálogo.
  /// Mapea a: DELETE /courses/{course_id}
  Future<void> deleteCourse(String courseId) async {
    try {
      final response = await _dio.delete('/courses/$courseId');
      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('No se pudo eliminar el curso (código ${response.statusCode}).');
      }
    } on DioException catch (e) {
      throw Exception(_manejarErrorDio(e));
    }
  }

  // --- ASISTENTE INTERNO DE ERRORES ---

  /// Procesa los fallos de DioException para extraer mensajes legibles y específicos.
  String _manejarErrorDio(DioException e) {
    if (e.response != null && e.response?.data != null) {
      final dynamic data = e.response?.data;
      if (data is Map && data.containsKey('detail')) {
        return data['detail'].toString();
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Tiempo de espera de conexión agotado.';
      case DioExceptionType.receiveTimeout:
        return 'El servidor tardó demasiado en responder.';
      case DioExceptionType.badResponse:
        return 'Error en el servidor (${e.response?.statusCode}).';
      default:
        return 'Error de conexión a la red. Verifica tu internet.';
    }
  }
}