import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_drawer.dart';

/// Pantalla del Administrador para la gestión del catálogo de cursos.
/// Conectada a GET/POST/PATCH/DELETE /courses/ del backend.
class CursosAdminScreen extends StatefulWidget {
  const CursosAdminScreen({super.key});

  @override
  State<CursosAdminScreen> createState() => _CursosAdminScreenState();
}

class _CursosAdminScreenState extends State<CursosAdminScreen> {
  final Color _colorMoradoCorporativo = const Color(0xFF766BE3);
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codigoController;
  late TextEditingController _nombreController;

  // ─── Estado de la lista ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _cursos = [];
  bool _cargando = true;
  String? _error;

  // ─── Estado del diálogo (crear/editar) ─────────────────────────────────
  bool _guardandoDialogo = false;
  String? _errorDialogo;

  @override
  void initState() {
    super.initState();
    _codigoController = TextEditingController();
    _nombreController = TextEditingController();
    _cargarCursos();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  // ─── Red ──────────────────────────────────────────────────────────────
  Future<void> _cargarCursos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final cursos = await ApiService().getCourses();
      setState(() {
        _cursos = cursos;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _limpiarFormulario() {
    _codigoController.clear();
    _nombreController.clear();
    _errorDialogo = null;
  }

  /// Despliega el formulario modal para la creación o modificación de un curso.
  void _mostrarDialogoCurso({int? index}) {
    final bool esEdicion = index != null;
    _errorDialogo = null;
    _guardandoDialogo = false;

    if (esEdicion) {
      final curso = _cursos[index];
      _codigoController.text = curso['codigo_curso']?.toString() ?? '';
      _nombreController.text = curso['nombre_curso']?.toString() ?? '';
    } else {
      _limpiarFormulario();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!_formKey.currentState!.validate()) return;
              setDialogState(() {
                _guardandoDialogo = true;
                _errorDialogo = null;
              });
              try {
                if (esEdicion) {
                  await ApiService().updateCourse(
                    courseId: _cursos[index]['id'].toString(),
                    nombreCurso: _nombreController.text.trim(),
                    codigoCurso: _codigoController.text.trim().toUpperCase(),
                  );
                } else {
                  await ApiService().createCourse(
                    nombreCurso: _nombreController.text.trim(),
                    codigoCurso: _codigoController.text.trim().toUpperCase(),
                  );
                }
                _limpiarFormulario();
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _cargarCursos(); // refresca la lista desde el backend
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
                width: 450,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esEdicion ? 'MODIFICAR CURSO' : 'NUEVO CURSO',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          esEdicion ? 'Actualiza los datos del curso seleccionado' : 'Agregar un curso al catálogo',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        _buildLabel('Código del curso'),
                        TextFormField(
                          controller: _codigoController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: _buildInputDecoration('Ej. MAT-001'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel('Nombre del curso'),
                        TextFormField(
                          controller: _nombreController,
                          decoration: _buildInputDecoration('Ej. Matemáticas'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                        ),

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
                              onPressed: _guardandoDialogo
                                  ? null
                                  : () {
                                _limpiarFormulario();
                                Navigator.pop(dialogContext);
                              },
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
                                backgroundColor: _colorMoradoCorporativo,
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

  /// Lanza una ventana modal de advertencia para confirmar la baja de un curso.
  void _confirmarEliminarCurso(int index) {
    final curso = _cursos[index];
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('¿Está seguro de eliminar este curso?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          content: Text(
            'Esta acción eliminará permanentemente el curso ${curso['nombre_curso']} del catálogo del sistema.',
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
                  await ApiService().deleteCourse(curso['id'].toString());
                  _cargarCursos();
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
            onPressed: _cargarCursos,
          ),
        ],
      ),
      drawer: const AdminDrawer(rutaActiva: '/admin/cursos'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cursos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ElevatedButton.icon(
                    onPressed: () => _mostrarDialogoCurso(),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text('Nuevo curso', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorMoradoCorporativo,
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
              else if (_cursos.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: const Text(
                      'Todavía no hay cursos registrados. Crea el primero con "Nuevo curso".',
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
                        width: 640,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              color: const Color(0xFFFAFAFA),
                              child: const Row(
                                children: [
                                  SizedBox(width: 130, child: Text('CÓDIGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  Expanded(child: Text('CURSO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                  SizedBox(width: 110, child: Text('SECCIONES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                  SizedBox(width: 100, child: SizedBox()),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: Colors.black12),

                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _cursos.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              itemBuilder: (context, index) {
                                final curso = _cursos[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 130,
                                        child: Text(
                                          curso['codigo_curso']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          curso['nombre_curso']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          (curso['total_secciones'] ?? 0).toString(),
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black54),
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              onPressed: () => _mostrarDialogoCurso(index: index),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                              constraints: const BoxConstraints(),
                                              padding: const EdgeInsets.all(6),
                                              onPressed: () => _confirmarEliminarCurso(index),
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
          TextButton(onPressed: _cargarCursos, child: const Text('Reintentar')),
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
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _colorMoradoCorporativo, width: 1.5)),
    );
  }
}