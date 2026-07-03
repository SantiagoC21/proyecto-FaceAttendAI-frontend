import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/attendance_models.dart';
import 'package:face_attend_ai/profesor/verificacion.dart';
import 'foto_anotada.dart';

class ResultadosAsistencia extends StatefulWidget {
  const ResultadosAsistencia({super.key});

  @override
  State<ResultadosAsistencia> createState() => _ResultadosAsistenciaState();
}

class _ResultadosAsistenciaState extends State<ResultadosAsistencia> {
  final Color _colorMorado = const Color(0xFF766BE3);

  List<Map<String, dynamic>> _alumnos = [];
  bool _cargando = true;
  bool _error = false;
  String _errorMensaje = '';
  String _similitudMedia = '0.0%';
  String _idSesion = '';
  SessionResults? _resultadosCompletos;

  // Tus datos simulados exactos (Plan B si no hay backend activo)
  final List<Map<String, dynamic>> _alumnosSimulados = [
    {'nombre': 'Lazo Quispe, Fernando', 'estado': 'Revisión', 'similitud': '68%', 'verificado': 'Pendiente'},
    {'nombre': 'Ochoa Torres, Sebastián', 'estado': 'Revisión', 'similitud': '61%', 'verificado': 'Pendiente'},
    {'nombre': 'Torres Lazo, Mariana', 'estado': 'Revisión', 'similitud': '57%', 'verificado': 'Pendiente'},
    {'nombre': 'Ccallo Ramos, Diego', 'estado': 'Presente', 'similitud': '94%', 'verificado': 'Automático'},
    {'nombre': 'Condori Torres, Lucía', 'estado': 'Presente', 'similitud': '87%', 'verificado': 'Automático'},
    {'nombre': 'García Sánchez, Miguel', 'estado': 'Presente', 'similitud': '91%', 'verificado': 'Automático'},
    {'nombre': 'Huanca Mamani, Valeria', 'estado': 'Presente', 'similitud': '88%', 'verificado': 'Automático'},
    {'nombre': 'Mamani Quispe, Andrea', 'estado': 'Presente', 'similitud': '95%', 'verificado': 'Automático'},
    {'nombre': 'Paucar Flores, Isabella', 'estado': 'Presente', 'similitud': '89%', 'verificado': 'Automático'},
    {'nombre': 'Quispe Mamani, José', 'estado': 'Presente', 'similitud': '76%', 'verificado': 'Automático'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // ✨ CORREGIDO: Extrae los argumentos de forma segura sin importar su tipo
      final Object? argumentos = ModalRoute.of(context)?.settings.arguments;
      String idSesion = 'mock-session-uuid-12345';

      // Si viene del portal profesor (un String puro con el UUID)
      if (argumentos is String) {
        idSesion = argumentos;
      }
      // Si viene del dashboard admin: puede traer un id_sesion real (Ver sesión
      // puntual) o solo el rol (vista genérica sin sesión real → Plan B).
      else if (argumentos is Map) {
        final idSesionReal = argumentos['id_sesion'];
        idSesion = idSesionReal != null ? idSesionReal.toString() : 'mock-session-uuid-12345';
      }

      setState(() {
        _idSesion = idSesion;
      });
      _obtenerResultadosReales(idSesion);
    });
  }
  /// Traduce el status crudo del backend ("present"/"absent"/"manual_check")
  /// a las etiquetas en español que usa la UI.
  String _estadoApp(String statusBackend) {
    switch (statusBackend) {
      case 'present':
        return 'Presente';
      case 'manual_check':
        return 'Revisión';
      case 'absent':
      default:
        return 'Ausente';
    }
  }

  Future<void> _obtenerResultadosReales(String idSesion) async {
    if (idSesion == 'mock-session-uuid-12345' || idSesion.isEmpty) {
      _cargarSimulacion();
      return;
    }
    try {
      // Llamada real a GET /sessions/{id}/results, usando el modelo tipado
      // SessionResults que ya coincide con el schema SessionResultsOut del backend.
      final resultados = await ApiService().getSessionResults(idSesion);
      _resultadosCompletos = resultados;

      double sumaSimilitud = 0.0;
      final alumnosCargados = resultados.records.map((r) {
        final double score = r.confidenceScore * 100;
        sumaSimilitud += score;
        final String estadoApp = _estadoApp(r.status);

        return {
          'id_registro': r.id,
          'nombre': r.estudianteNombre ?? 'Rostro sin identificar',
          'estado': estadoApp,
          'similitud': '${score.toStringAsFixed(0)}%',
          'verificado': r.verificado ? 'Manual' : (estadoApp == 'Revisión' ? 'Pendiente' : 'Automático'),
        };
      }).toList();

      setState(() {
        _alumnos = alumnosCargados;
        _similitudMedia = _alumnos.isEmpty
            ? '0.0%'
            : '${(sumaSimilitud / _alumnos.length).toStringAsFixed(1)}%';
        _cargando = false;
        _error = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = true;
        _errorMensaje = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _cargarSimulacion() {
    setState(() {
      _alumnos = _alumnosSimulados;
      _similitudMedia = '82.4%';
      _cargando = false;
    });
  }

  int get _conteoPendientes => _alumnos.where((a) => a['estado'] == 'Revisión').length;
  int get _conteoPresentes => _alumnos.where((a) => a['estado'] == 'Presente').length;
  int get _conteoAusentes => _alumnos.where((a) => a['estado'] == 'Ausente').length;
  int get _buildTotalPresentes => _conteoPresentes;

  @override
  Widget build(BuildContext context) {
    // ✨ CORREGIDO: Lectura inteligente y tolerante de argumentos para evitar el pantallazo rojo
    final Object? rawArgs = ModalRoute.of(context)?.settings.arguments;
    String rol = 'profesor';

    if (rawArgs is Map<String, dynamic>) {
      rol = rawArgs['rol'] ?? 'profesor';
    } else if (rawArgs is Map) {
      rol = rawArgs['rol']?.toString() ?? 'profesor';
    }

    final bool esAdminEspectador = rol == 'admin';
    // Obtenemos la fecha formateada de hoy
    final DateTime ahora = DateTime.now();
    final String fechaStr = "${ahora.day} jun ${ahora.year} • ${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      // ✨ CORREGIDO: Se remueve el drawer por completo para que no aparezcan las 3 líneas vacías
      drawer: null,
      appBar: AppBar(
        title: Text(
            esAdminEspectador ? 'Auditoría de Asistencia — INF-321' : 'Resultados — INF-321',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: _colorMorado,
        iconTheme: const IconThemeData(color: Colors.white),
        // ✨ CORREGIDO: Ambos roles disponen ahora de una flecha limpia de retroceso técnico
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (esAdminEspectador) {
              Navigator.pop(context);
            } else {
              // Limpia el historial intermedio de la sesión y retorna estable al Dashboard
              Navigator.popUntil(context, ModalRoute.withName('/profesor/dashboard'));
            }
          },
        ),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error
            ? Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.black26),
                const SizedBox(height: 16),
                const Text(
                  'No se pudieron cargar los resultados',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMensaje,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _cargando = true);
                    _obtenerResultadosReales(_idSesion);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _colorMorado),
                  child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resultados — INF-321 Planeamiento Estratégico',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                '$fechaStr • Procesado en 18 s • ${_alumnos.length} estudiantes analizados',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 25),
              if (_resultadosCompletos?.panoramaUrl != null) ...[
                const SizedBox(height: 16),
                FotoAnotadaCard(
                  panoramaUrl: _resultadosCompletos!.panoramaUrl!,
                  records: _resultadosCompletos!.records,
                ),
              ],
              const SizedBox(height: 25),

              // --- CUADRÍCULA DE MÉTRICAS ---
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: [
                  _buildCardMetrica('Presentes', '$_buildTotalPresentes', const Color(0xEFE8F5E9), Colors.green[800]!),
                  _buildCardMetrica('Revisión manual', '$_conteoPendientes', const Color(0xFFFFFDE7), Colors.amber[800]!, icono: Icons.warning_amber_rounded),
                  _buildCardMetrica('Ausentes', '$_conteoAusentes', const Color(0xFFFFEBEE), Colors.red[800]!),
                  _buildCardMetrica('Similitud media', _similitudMedia, Colors.white, Colors.black87, conBorde: true),
                ],
              ),
              const SizedBox(height: 20),

              // --- BANNER DE ADVERTENCIA DINÁMICO ---
              if (_conteoPendientes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFBC02D).withAlpha(100)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_conteoPendientes registros requieren tu verificación',
                                style: TextStyle(fontSize: 13, color: Colors.amber[900], fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!esAdminEspectador)
                        ElevatedButton(
                          onPressed: () async {
                            final listaActualizada = await Navigator.push<List<Map<String, dynamic>>>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VerificacionManual(
                                  alumnosIniciales: _alumnos,
                                  idSesion: _idSesion,
                                ),
                              ),
                            );

                            if (listaActualizada != null) {
                              setState(() {
                                _alumnos = listaActualizada;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AC0D),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Revisar ahora', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              if (_conteoPendientes > 0) const SizedBox(height: 25),

              // --- TABLA DE ALUMNOS ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 600,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            child: Row(
                              children: [
                                SizedBox(width: 240, child: Text('ESTUDIANTE', style: _estiloEncabezado())),
                                SizedBox(width: 120, child: Text('ESTADO', style: _estiloEncabezado())),
                                SizedBox(width: 100, child: Text('SIMILITUD', style: _estiloEncabezado(alinearDerecha: true))),
                                SizedBox(width: 116, child: Text('VERIFICADO', style: _estiloEncabezado(alinearDerecha: true))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _alumnos.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                            itemBuilder: (context, index) {
                              final alumno = _alumnos[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 240,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 14,
                                            backgroundColor: _colorMorado.withAlpha(30),
                                            child: Text(
                                              alumno['nombre']!.substring(0, 2).toUpperCase(),
                                              style: TextStyle(fontSize: 11, color: _colorMorado, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              alumno['nombre']!,
                                              style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildBadgeEstado(alumno['estado']!),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        alumno['similitud']!,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 116,
                                      child: Text(
                                        alumno['verificado']!,
                                        textAlign: TextAlign.end,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: alumno['verificado'] == 'Pendiente' ? Colors.grey[600] : Colors.grey[400]
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ✨ NUEVO: Botón premium para retornar directamente a "Mis secciones"
              if (!esAdminEspectador) ...[
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, ModalRoute.withName('/profesor/dashboard'));
                    },
                    icon: const Icon(Icons.apps_rounded, size: 18),
                    label: const Text('Volver a Mis secciones'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _colorMorado,
                      side: BorderSide(color: _colorMorado, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _estiloEncabezado({bool alinearDerecha = false}) {
    return TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5);
  }

  Widget _buildBadgeEstado(String estado) {
    Color fondo = const Color(0xFFFFFDE7);
    Color texto = Colors.amber[800]!;
    if (estado == 'Presente') {
      fondo = const Color(0xEFE8F5E9);
      texto = Colors.green[700]!;
    } else if (estado == 'Ausente') {
      fondo = const Color(0xFFFFEBEE);
      texto = Colors.red[700]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Text(estado, style: TextStyle(color: texto, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCardMetrica(String titulo, String valor, Color fondo, Color colorTexto, {IconData? icono, bool conBorde = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8), border: conBorde ? Border.all(color: Colors.grey[200]!) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (icono != null) Icon(icono, color: colorTexto, size: 16),
            ],
          ),
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorTexto)),
        ],
      ),
    );
  }
}