import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_drawer.dart';
import 'estudiantes.dart';

/// Días de la semana tal como los espera el backend (dia_semana: int, 1=Lunes).
const Map<int, String> _diasSemana = {
  1: 'Lunes',
  2: 'Martes',
  3: 'Miércoles',
  4: 'Jueves',
  5: 'Viernes',
  6: 'Sábado',
  7: 'Domingo',
};

class SeccionesAdminScreen extends StatefulWidget {
  const SeccionesAdminScreen({super.key});

  @override
  State<SeccionesAdminScreen> createState() => _SeccionesAdminScreenState();
}

class _SeccionesAdminScreenState extends State<SeccionesAdminScreen> {
  final Color _colorMorado = const Color(0xFF766BE3);

  // ─── Estado de la lista ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _secciones = [];
  List<Map<String, dynamic>> _cursos = [];
  List<Map<String, dynamic>> _profesores = [];
  bool _cargando = true;
  String? _error;

  // ─── Estado del diálogo (crear/editar) ─────────────────────────────────
  bool _guardandoDialogo = false;
  String? _errorDialogo;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ─── Red ──────────────────────────────────────────────────────────────
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService().getSections(),
        ApiService().getCourses(),
        ApiService().getUsers(rol: 'teacher'),
      ]);
      setState(() {
        _secciones = resultados[0];
        _cursos = resultados[1];
        _profesores = resultados[2];
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _formatearHora(String? horaCompleta) {
    // El backend devuelve 'HH:MM:SS'; el formulario solo edita 'HH:MM'.
    if (horaCompleta == null || horaCompleta.length < 5) return '';
    return horaCompleta.substring(0, 5);
  }

  /// Despliega el formulario modal para crear o editar una sección.
  void _mostrarDialogoSeccion({int? index}) {
    final bool esEdicion = index != null;

    if (!esEdicion && (_cursos.isEmpty || _profesores.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _cursos.isEmpty
                ? 'Primero crea al menos un curso en la pantalla "Cursos".'
                : 'No hay usuarios con rol de profesor registrados todavía.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final Map<String, dynamic>? seccion = esEdicion ? _secciones[index] : null;

    String? cursoSeleccionadoId;
    String textoCursoActual = '';
    String textoProfesorActual = 'No se puede cambiar desde aquí';
    int totalInscritosActual = 0;
    if (esEdicion && seccion != null) {
      final cursoData = seccion['curso'] as Map<String, dynamic>?;
      cursoSeleccionadoId = cursoData?['id']?.toString();
      final codigoCurso = cursoData?['codigo_curso']?.toString() ?? '';
      final nombreCurso = cursoData?['nombre_curso']?.toString() ?? '';
      textoCursoActual = '$codigoCurso — $nombreCurso';
      textoProfesorActual = seccion['profesor_nombre']?.toString() ?? textoProfesorActual;
      totalInscritosActual = (seccion['total_inscritos'] ?? 0) as int;
    }
    String? profesorSeleccionadoId; // Solo aplica al crear; no editable en PATCH.

    final codigoController = TextEditingController(text: seccion?['codigo_seccion']?.toString() ?? '');
    final aulaController = TextEditingController(text: seccion?['aula']?.toString() ?? '');
    final inicioController = TextEditingController(text: _formatearHora(seccion?['hora_inicio']?.toString()));
    final finController = TextEditingController(text: _formatearHora(seccion?['hora_fin']?.toString()));
    int diaSeleccionado = (seccion?['dia_semana'] as int?) ?? 1;

    _errorDialogo = null;
    _guardandoDialogo = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() {
                _guardandoDialogo = true;
                _errorDialogo = null;
              });
              try {
                if (esEdicion) {
                  await ApiService().updateSection(
                    sectionId: seccion!['id'].toString(),
                    codigoSeccion: codigoController.text.trim(),
                    diaSemana: diaSeleccionado,
                    horaInicio: inicioController.text.trim(),
                    horaFin: finController.text.trim(),
                    aula: aulaController.text.trim(),
                  );
                } else {
                  await ApiService().createSection(
                    idCurso: cursoSeleccionadoId!,
                    idProfesor: profesorSeleccionadoId!,
                    codigoSeccion: codigoController.text.trim(),
                    diaSemana: diaSeleccionado,
                    horaInicio: inicioController.text.trim(),
                    horaFin: finController.text.trim(),
                    aula: aulaController.text.trim().isEmpty ? null : aulaController.text.trim(),
                  );
                }
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _cargarDatos();
              } catch (e) {
                setDialogState(() {
                  _guardandoDialogo = false;
                  _errorDialogo = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              surfaceTintColor: Colors.transparent,
              contentPadding: const EdgeInsets.all(24.0),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'EDITAR SECCIÓN' : 'NUEVA SECCIÓN',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          esEdicion ? 'Actualiza el horario o los datos de la sección' : 'Crea una sección y asígnale un profesor',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        _buildLabel('Curso'),
                        if (esEdicion)
                          TextFormField(
                            initialValue: '${seccion!['curso']?['codigo_curso'] ?? ''} — ${seccion['curso']?['nombre_curso'] ?? ''}',
                            enabled: false,
                            style: const TextStyle(color: Colors.black54),
                            decoration: _buildInputDecoration('').copyWith(fillColor: const Color(0xFFF5F5F5), filled: true),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: cursoSeleccionadoId,
                            hint: const Text('Seleccionar curso', style: TextStyle(fontSize: 14, color: Colors.black26)),
                            decoration: _buildInputDecoration(''),
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            items: _cursos.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text(
                                  '${c['codigo_curso']} — ${c['nombre_curso']}',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => cursoSeleccionadoId = v,
                            validator: (v) => v == null ? 'Selecciona un curso' : null,
                          ),
                        const SizedBox(height: 16),

                        _buildLabel('Código de sección'),
                        TextFormField(
                          controller: codigoController,
                          decoration: _buildInputDecoration('Ej. G1, 3°B'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Profesor'),
                        if (esEdicion)
                          TextFormField(
                            initialValue: seccion!['profesor_nombre']?.toString() ??
                                'No se puede cambiar desde aquí',
                            enabled: false,
                            style: const TextStyle(color: Colors.black54),
                            decoration: _buildInputDecoration('').copyWith(fillColor: const Color(0xFFF5F5F5), filled: true),
                          )
                        else
                          DropdownButtonFormField<String>(
                            initialValue: profesorSeleccionadoId,
                            hint: const Text('Seleccionar profesor', style: TextStyle(fontSize: 14, color: Colors.black26)),
                            decoration: _buildInputDecoration(''),
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            items: _profesores.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['id'].toString(),
                                child: Text(
                                  p['nombre_completo']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => profesorSeleccionadoId = v,
                            validator: (v) => v == null ? 'Selecciona un profesor' : null,
                          ),
                        const SizedBox(height: 16),

                        _buildLabel('Día y horario'),
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<int>(
                                initialValue: diaSeleccionado,
                                isExpanded: true,
                                decoration: _buildInputDecoration(''),
                                dropdownColor: Colors.white,
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                items: _diasSemana.entries.map((e) {
                                  return DropdownMenuItem<int>(
                                    value: e.key,
                                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (v) => setDialogState(() => diaSeleccionado = v!),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: inicioController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: _buildInputDecoration('08:00'),
                                validator: (v) => (v == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(v))
                                    ? 'HH:MM'
                                    : null,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text('–', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: finController,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13),
                                decoration: _buildInputDecoration('09:30'),
                                validator: (v) => (v == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(v))
                                    ? 'HH:MM'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Aula (opcional)'),
                        TextFormField(
                          controller: aulaController,
                          decoration: _buildInputDecoration('Ej. Aula 302'),
                        ),

                        if (esEdicion) ...[
                          const SizedBox(height: 16),
                          _buildLabel('Alumnos inscritos'),
                          TextFormField(
                            initialValue: (seccion!['total_inscritos'] ?? 0).toString(),
                            enabled: false,
                            style: const TextStyle(color: Colors.black54),
                            decoration: _buildInputDecoration('').copyWith(fillColor: const Color(0xFFF5F5F5), filled: true),
                          ),
                        ],

                        if (_errorDialogo != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_errorDialogo!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _guardandoDialogo ? null : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text('Cancelar', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _guardandoDialogo ? null : guardar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _colorMorado,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              child: _guardandoDialogo
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmarEliminarSeccion(int index) {
    final seccion = _secciones[index];
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('¿Está seguro de eliminar esta sección?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: Text(
            'Eliminará la sección ${seccion['codigo_seccion']} del curso ${seccion['curso']?['nombre_curso'] ?? ''}, junto con sus inscripciones.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ApiService().deleteSection(seccion['id'].toString());
                  _cargarDatos();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
            onPressed: _cargarDatos,
          ),
        ],
      ),
      drawer: const AdminDrawer(rutaActiva: '/admin/secciones'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Secciones', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoSeccion(),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Nueva sección', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorMorado,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else if (_secciones.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Text(
                      'Todavía no hay secciones registradas. Crea la primera con "Nueva sección".',
                      style: TextStyle(color: Colors.black38, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 1000,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              color: const Color(0xFFFAFAFA),
                              child: const Row(
                                children: [
                                  SizedBox(width: 90, child: Text('SECCIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  SizedBox(width: 180, child: Text('CURSO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  SizedBox(width: 200, child: Text('PROFESOR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  Expanded(child: Text('HORARIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  SizedBox(width: 80, child: Text('ALUMNOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                  SizedBox(width: 160, child: SizedBox()),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.black12),

                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _secciones.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              itemBuilder: (context, index) {
                                final sec = _secciones[index];
                                final curso = sec['curso'] as Map<String, dynamic>?;
                                final String horario =
                                    '${_diasSemana[sec['dia_semana']] ?? ''} ${_formatearHora(sec['hora_inicio']?.toString())}–${_formatearHora(sec['hora_fin']?.toString())}';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 90, child: Text(sec['codigo_seccion']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))),
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          curso?['nombre_curso']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          sec['profesor_nombre']?.toString() ?? '—',
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(horario, style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500)),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          (sec['total_inscritos'] ?? 0).toString(),
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 160,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => EstudiantesAdminScreen(
                                                      sectionId: sec['id'].toString(),
                                                      nombreCurso: curso?['nombre_curso']?.toString() ?? '',
                                                      seccion: sec['codigo_seccion']?.toString() ?? '',
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: Icon(Icons.people_outline, size: 16, color: _colorMorado),
                                              label: Text('Ver alumnos', style: TextStyle(fontSize: 11, color: _colorMorado, fontWeight: FontWeight.bold)),
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: const Size(50, 30),
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              onPressed: () => _mostrarDialogoSeccion(index: index),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(4),
                                              onPressed: () => _confirmarEliminarSeccion(index),
                                            ),
                                          ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.black26),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.black54, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: _cargarDatos, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _colorMorado, width: 1.5)),
    );
  }
}