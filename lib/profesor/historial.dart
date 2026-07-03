import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profesor_drawer.dart'; // ✨ Importamos el menú lateral unificado

class Historial extends StatefulWidget {
  const Historial({super.key});

  @override
  State<Historial> createState() => _HistorialState();
}

class _HistorialState extends State<Historial> {
  final Color _colorMorado = const Color(0xFF766BE3);

  // ─── Secciones del profesor (para el selector) ─────────────────────────────
  List<Map<String, dynamic>> _secciones = [];
  bool _cargandoSecciones = true;
  String? _errorSecciones;

  // ─── Sección seleccionada e historial de sesiones ──────────────────────────
  String? _seccionSeleccionadaId;
  List<Map<String, dynamic>> _sesionesActuales = [];
  bool _cargandoHistorial = false;
  String? _errorHistorial;

  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  // ─── Red: carga las secciones asignadas al profesor ────────────────────────
  Future<void> _cargarSecciones() async {
    setState(() {
      _cargandoSecciones = true;
      _errorSecciones = null;
    });
    try {
      final secciones = await ApiService().getSections();
      setState(() {
        _secciones = secciones;
        _cargandoSecciones = false;
      });
    } catch (e) {
      setState(() {
        _cargandoSecciones = false;
        _errorSecciones = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─── Red: carga el historial de sesiones de la sección elegida ─────────────
  Future<void> _cargarHistorialSeccion(String sectionId) async {
    setState(() {
      _cargandoHistorial = true;
      _errorHistorial = null;
      _sesionesActuales = [];
    });
    try {
      final historial = await ApiService().getSectionHistory(sectionId);

      // Traducimos SessionHistoryOut (id, fecha_sesion, status_proceso,
      // total_inscritos, total_presentes, porcentaje_asistencia) al formato
      // que usa esta pantalla. El backend no desglosa "revisión manual" por
      // sesión, así que "ausentes" agrupa a todos los no marcados "present".
      final sesiones = historial.map((s) {
        final int totalInscritos = (s['total_inscritos'] ?? 0) as int;
        final int totalPresentes = (s['total_presentes'] ?? 0) as int;
        return {
          'id': s['id'].toString(),
          'fecha': _formatearFecha(s['fecha_sesion']?.toString() ?? ''),
          'status_proceso': s['status_proceso']?.toString() ?? '',
          'presentes': totalPresentes,
          'ausentes': (totalInscritos - totalPresentes).clamp(0, totalInscritos),
          'porcentaje': ((s['porcentaje_asistencia'] ?? 0) as num).round(),
        };
      }).toList();

      setState(() {
        _sesionesActuales = sesiones;
        _cargandoHistorial = false;
      });
    } catch (e) {
      setState(() {
        _cargandoHistorial = false;
        _errorHistorial = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatearFecha(String isoFecha) {
    // fecha_sesion llega como 'YYYY-MM-DD'
    try {
      final partes = isoFecha.split('-');
      if (partes.length != 3) return isoFecha;
      const dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      const meses = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final fecha = DateTime.parse(isoFecha);
      final diaSemana = dias[fecha.weekday - 1];
      final mes = meses[fecha.month - 1];
      return '$diaSemana, ${fecha.day} $mes.';
    } catch (_) {
      return isoFecha;
    }
  }

  String _nombreSeccion(Map<String, dynamic> seccion) {
    final curso = seccion['curso'] as Map<String, dynamic>?;
    final codigoCurso = curso?['codigo_curso']?.toString() ?? '';
    final nombreCurso = curso?['nombre_curso']?.toString() ?? '';
    final codigoSeccion = seccion['codigo_seccion']?.toString() ?? '';
    return '$codigoCurso $nombreCurso ($codigoSeccion)';
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {
              _cargarSecciones();
              if (_seccionSeleccionadaId != null) {
                _cargarHistorialSeccion(_seccionSeleccionadaId!);
              }
            },
          ),
        ],
      ),

      drawer: const ProfesorDrawer(rutaActiva: '/profesor/historial'),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              // ── Selector de sección ──────────────────────────────────────
              _buildSelectorSeccion(),
              const SizedBox(height: 28),

              if (_seccionSeleccionadaId == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: const Text(
                    'Por favor, seleccione una sección para visualizar las métricas históricas.',
                    style: TextStyle(color: Colors.black38, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_cargandoHistorial)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorHistorial != null)
                  _buildErrorHistorial()
                else if (_sesionesActuales.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const Text(
                        'Esta sección aún no tiene sesiones de asistencia registradas.',
                        style: TextStyle(color: Colors.black38, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else ...[
                      // 📊 1. GRÁFICA DE BARRAS APILADAS CON DESPLAZAMIENTO HORIZONTAL
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                reverse: true,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _sesionesActuales.reversed.map((sesion) {
                                    return _buildBarraApiladaInteractiva(sesion);
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildLeyendaItem('Presentes', Colors.green),
                                  const SizedBox(width: 16),
                                  _buildLeyendaItem('Ausentes', Colors.redAccent),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 📋 2. TABLA DETALLADA DE CLASES (De más reciente a más antigua)
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 860,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  color: const Color(0xFFFAFAFA),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 140, child: Text('FECHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                      SizedBox(width: 120, child: Text('PRESENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                      SizedBox(width: 120, child: Text('AUSENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                      Expanded(child: Text('% ASISTENCIA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                      SizedBox(width: 120, child: Text('ACCIONES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1, color: Colors.black12),

                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _sesionesActuales.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  itemBuilder: (context, index) {
                                    final sesion = _sesionesActuales[index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 140, child: Text(sesion['fecha'], style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500))),
                                          SizedBox(width: 120, child: Center(child: Text('${sesion['presentes']}', style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)))),
                                          SizedBox(width: 120, child: Center(child: Text('${sesion['ausentes']}', style: const TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 100,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: LinearProgressIndicator(
                                                      value: (sesion['porcentaje'] as int) / 100,
                                                      minHeight: 6,
                                                      backgroundColor: Colors.grey[100],
                                                      valueColor: AlwaysStoppedAnimation<Color>(_colorMorado),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text('${sesion['porcentaje']}%', style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 120,
                                            child: Center(
                                              child: TextButton(
                                                onPressed: sesion['status_proceso'] == 'completed'
                                                    ? () {
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/profesor/resultados',
                                                    arguments: sesion['id'] as String,
                                                  );
                                                }
                                                    : null,
                                                child: Text(
                                                  sesion['status_proceso'] == 'completed' ? 'Ver detalle' : 'Sin procesar',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: sesion['status_proceso'] == 'completed' ? _colorMorado : Colors.black26,
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
                      ),
                    ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget: selector de sección con manejo de carga/error ────────────────
  Widget _buildSelectorSeccion() {
    if (_cargandoSecciones) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_errorSecciones != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEF9A9A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_errorSecciones!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ),
            TextButton(onPressed: _cargarSecciones, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_secciones.isEmpty) {
      return const Text(
        'No tienes secciones asignadas todavía.',
        style: TextStyle(color: Colors.black38, fontSize: 13),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _seccionSeleccionadaId,
          hint: const Text('Seleccionar sección', style: TextStyle(fontSize: 14, color: Colors.black38)),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          items: _secciones.map((seccion) {
            final id = seccion['id'].toString();
            return DropdownMenuItem<String>(
              value: id,
              child: Text(
                _nombreSeccion(seccion),
                style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (nuevaSeccionId) {
            setState(() => _seccionSeleccionadaId = nuevaSeccionId);
            if (nuevaSeccionId != null) {
              _cargarHistorialSeccion(nuevaSeccionId);
            }
          },
        ),
      ),
    );
  }

  Widget _buildErrorHistorial() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(
            _errorHistorial!,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _cargarHistorialSeccion(_seccionSeleccionadaId!),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // Generador dinámico de la gráfica de barras apiladas por cada fecha
  Widget _buildBarraApiladaInteractiva(Map<String, dynamic> sesion) {
    int pres = sesion['presentes'] as int;
    int aus = sesion['ausentes'] as int;
    int total = pres + aus;

    double scale = 160.0 / (total > 0 ? total : 1);

    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.85), borderRadius: BorderRadius.circular(6)),
      richMessage: TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        children: [
          TextSpan(text: '${sesion['fecha']}\n', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: '• Presentes: $pres\n', style: const TextStyle(color: Colors.greenAccent)),
          TextSpan(text: '• Ausentes: $aus', style: const TextStyle(color: Colors.redAccent)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (aus > 0) Container(width: 44, height: aus * scale, color: Colors.redAccent),
                  if (pres > 0) Container(width: 44, height: pres * scale, color: Colors.green),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sesion['fecha'].toString().replaceAll(RegExp(r'^\w+,\s'), ''),
              style: const TextStyle(fontSize: 11, color: Colors.black45, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyendaItem(String texto, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
      ],
    );
  }
}