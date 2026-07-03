import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_drawer.dart';

/// Pantalla principal del panel de control del Administrador.
/// Combina varios endpoints (no hay uno solo de "resumen" en el backend)
/// para mostrar métricas globales, alertas de embeddings y sesiones recientes.
class DashboardAdmin extends StatefulWidget {
  const DashboardAdmin({super.key});

  @override
  State<DashboardAdmin> createState() => _DashboardAdminState();
}

class _DashboardAdminState extends State<DashboardAdmin> {
  bool _cargando = true;
  String? _error;

  int _estudiantesRegistrados = 0;
  int _seccionesActivas = 0;
  int _cursosCount = 0;
  int _embeddingsRegistrados = 0;

  List<Map<String, String>> _alumnosSinEmbeddings = [];
  List<Map<String, dynamic>> _sesionesRecientes = [];

  final Color _colorMoradoCorporativo = const Color(0xFF766BE3);

  @override
  void initState() {
    super.initState();
    _cargarDatosDashboard();
  }

  // ─── Red ──────────────────────────────────────────────────────────────
  Future<void> _cargarDatosDashboard() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService().getStudents(),
        ApiService().getSections(),
        ApiService().getCourses(),
      ]);
      final List<Map<String, dynamic>> estudiantes = resultados[0];
      final List<Map<String, dynamic>> secciones = resultados[1];
      final List<Map<String, dynamic>> cursos = resultados[2];

      // El backend no tiene un endpoint que sume embeddings de todo el sistema,
      // así que pedimos el conteo de cada estudiante en paralelo y sumamos.
      final conteosEmbeddings = await Future.wait(
        estudiantes.map((e) => ApiService().getEmbeddingsCount(e['id'].toString())),
      );
      final int totalEmbeddings = conteosEmbeddings.fold<int>(0, (a, b) => a + b);

      final List<Map<String, String>> sinEmbeddings = [];
      for (int i = 0; i < estudiantes.length; i++) {
        if (conteosEmbeddings[i] == 0) {
          sinEmbeddings.add({
            'nombre': estudiantes[i]['nombre_completo']?.toString() ?? '',
            'codigo': estudiantes[i]['codigo_estudiante']?.toString() ?? '',
          });
        }
      }

      // Tampoco hay un endpoint de "sesiones recientes globales": traemos el
      // historial de cada sección en paralelo y las mezclamos todas.
      final historiales = await Future.wait(
        secciones.map((s) => ApiService().getSectionHistory(s['id'].toString())),
      );
      final List<Map<String, dynamic>> todasLasSesiones = [];
      for (int i = 0; i < secciones.length; i++) {
        final seccion = secciones[i];
        final curso = seccion['curso'] as Map<String, dynamic>?;
        for (final s in historiales[i]) {
          final int inscritos = (s['total_inscritos'] ?? 0) as int;
          final int presentes = (s['total_presentes'] ?? 0) as int;
          todasLasSesiones.add({
            'id': s['id'],
            'fecha_sesion': s['fecha_sesion']?.toString() ?? '',
            'status_proceso': s['status_proceso']?.toString() ?? '',
            'seccion_texto': '${seccion['codigo_seccion']} — ${curso?['nombre_curso'] ?? ''}',
            'presentes': presentes,
            'ausentes': (inscritos - presentes).clamp(0, inscritos),
          });
        }
      }
      todasLasSesiones.sort((a, b) => (b['fecha_sesion'] as String).compareTo(a['fecha_sesion'] as String));

      setState(() {
        _estudiantesRegistrados = estudiantes.length;
        _seccionesActivas = secciones.length;
        _cursosCount = cursos.length;
        _embeddingsRegistrados = totalEmbeddings;
        _alumnosSinEmbeddings = sinEmbeddings;
        _sesionesRecientes = todasLasSesiones.take(5).toList();
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatearFecha(String isoFecha) {
    try {
      const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      final fecha = DateTime.parse(isoFecha);
      return '${dias[fecha.weekday - 1]}, ${fecha.day} ${meses[fecha.month - 1]}.';
    } catch (_) {
      return isoFecha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime ahora = DateTime.now();
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    const dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    final String fechaHoyStr = '${dias[ahora.weekday - 1]}, ${ahora.day} de ${meses[ahora.month - 1]} de ${ahora.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Actualizar',
            onPressed: _cargarDatosDashboard,
          ),
        ],
      ),
      drawer: const AdminDrawer(rutaActiva: '/admin/dashboard'),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF766BE3)))
            : _error != null
            ? _buildError()
            : SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panel de administración',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                fechaHoyStr,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  double cardWidth = (constraints.maxWidth - 48) / 4;
                  if (constraints.maxWidth < 700) cardWidth = (constraints.maxWidth - 16) / 2;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildMetricaCard('Estudiantes registrados', _estudiantesRegistrados.toString(), Icons.school_outlined, cardWidth),
                      _buildMetricaCard('Secciones activas', _seccionesActivas.toString(), Icons.book_outlined, cardWidth),
                      _buildMetricaCard('Cursos', _cursosCount.toString(), Icons.assignment_outlined, cardWidth),
                      _buildMetricaCard('Embeddings registrados', _embeddingsRegistrados.toString(), Icons.fingerprint, cardWidth, isSpecial: true),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              if (_alumnosSinEmbeddings.isNotEmpty) _buildAlertaEmbeddings(),

              const SizedBox(height: 32),

              const Text(
                'SESIONES RECIENTES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              _sesionesRecientes.isEmpty
                  ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black12),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Todavía no hay sesiones de asistencia registradas en el sistema.',
                  style: TextStyle(color: Colors.black38, fontSize: 13),
                ),
              )
                  : _buildTablaSesiones(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.black26),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.black54, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargarDatosDashboard, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricaCard(String titulo, String valor, IconData icon, double width, {bool isSpecial = false}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isSpecial ? const Color(0xFFF0EEFF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSpecial ? const Color(0xFFDCD7FF) : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: isSpecial ? _colorMoradoCorporativo : Colors.black45, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valor,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaEmbeddings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD1D1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2.0),
                child: Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alumnos sin embeddings',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_alumnosSinEmbeddings.length} estudiantes no tienen fotos registradas y no podrán ser reconocidos',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFD32F2F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 34.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _alumnosSinEmbeddings.map((alumno) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    '•  ${alumno['nombre']} (${alumno['codigo']})',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 34.0),
            child: ElevatedButton.icon(
              onPressed: () {
                if (!mounted) return;
                Navigator.pushNamed(context, '/admin/secciones');
              },
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              label: const Text('Ir a Secciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaSesiones() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black12),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 650,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFFAFAFA),
                child: const Row(
                  children: [
                    SizedBox(width: 100, child: Text('FECHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                    SizedBox(width: 250, child: Text('SECCIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                    SizedBox(width: 110, child: Text('PRESENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                    SizedBox(width: 110, child: Text('AUSENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                    SizedBox(width: 48, child: SizedBox()),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.black12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _sesionesRecientes.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                itemBuilder: (context, index) {
                  final sesion = _sesionesRecientes[index];
                  final bool completada = sesion['status_proceso'] == 'completed';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(_formatearFecha(sesion['fecha_sesion'].toString()), style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ),
                        SizedBox(
                          width: 250,
                          child: Text(sesion['seccion_texto'].toString(), style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            sesion['presentes'].toString(),
                            style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            sesion['ausentes'].toString(),
                            style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: !completada
                                  ? null
                                  : () {
                                if (!mounted) return;
                                Navigator.pushNamed(
                                  context,
                                  '/profesor/resultados',
                                  arguments: {'rol': 'admin', 'id_sesion': sesion['id']},
                                );
                              },
                              child: Text(
                                'Ver',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: completada ? _colorMoradoCorporativo : Colors.black26,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
    );
  }
}