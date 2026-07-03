import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'embeddings.dart';

class EstudiantesAdminScreen extends StatefulWidget {
  final String sectionId;
  final String nombreCurso;
  final String seccion;

  const EstudiantesAdminScreen({
    super.key,
    required this.sectionId,
    this.nombreCurso = '',
    this.seccion = '',
  });

  @override
  State<EstudiantesAdminScreen> createState() => _EstudiantesAdminScreenState();
}

class _EstudiantesAdminScreenState extends State<EstudiantesAdminScreen> {
  final Color _colorMorado = const Color(0xFF766BE3);

  // ─── Estado de la lista ─────────────────────────────────────────────────
  List<Map<String, dynamic>> _inscritos = [];
  List<Map<String, dynamic>> _catalogoGlobal = [];
  bool _cargando = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  String _filtroBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Red ──────────────────────────────────────────────────────────────
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        ApiService().getEnrolledStudents(widget.sectionId),
        ApiService().getStudents(),
      ]);
      final List<Map<String, dynamic>> inscritos = resultados[0];
      final List<Map<String, dynamic>> catalogo = resultados[1];

      // El conteo de embeddings no viene incluido en /sections/{id}/students,
      // así que lo pedimos aparte, uno por estudiante, en paralelo.
      final conteos = await Future.wait(
        inscritos.map((e) => ApiService().getEmbeddingsCount(e['id_estudiante'].toString())),
      );

      final List<Map<String, dynamic>> inscritosConFotos = [];
      for (int i = 0; i < inscritos.length; i++) {
        inscritosConFotos.add({
          'id_inscripcion': inscritos[i]['id_inscripcion'],
          'id_estudiante': inscritos[i]['id_estudiante'],
          'nombre': inscritos[i]['nombre_completo'],
          'codigo': inscritos[i]['codigo_estudiante'],
          'fotos': conteos[i],
        });
      }

      setState(() {
        _inscritos = inscritosConFotos;
        _catalogoGlobal = catalogo;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _retirarEstudiante(Map<String, dynamic> est) async {
    try {
      await ApiService().unenrollStudent(
        sectionId: widget.sectionId,
        studentId: est['id_estudiante'].toString(),
      );
      setState(() => _inscritos.remove(est));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Generador de iniciales seguro que evita por completo el RangeError
  String _obtenerInicialesSeguras(String nombreCompleto) {
    if (nombreCompleto.trim().isEmpty) return 'ST';
    List<String> palabras = nombreCompleto.trim().split(' ');
    if (palabras.length >= 2) {
      String p1 = palabras[0].isNotEmpty ? palabras[0].substring(0, 1) : '';
      String p2 = palabras[1].isNotEmpty ? palabras[1].substring(0, 1) : '';
      return '$p1$p2'.toUpperCase();
    }
    return nombreCompleto.substring(0, nombreCompleto.length > 2 ? 2 : nombreCompleto.length).toUpperCase();
  }

  // Generador visual de etiquetas de Embeddings según la cantidad de fotos
  Widget _buildEmbeddingStatus(int fotos) {
    if (fotos >= 8) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
        child: const Text('✓ Listo', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    } else if (fotos >= 1 && fotos <= 7) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFFDE7), borderRadius: BorderRadius.circular(4)),
        child: Text('$fotos fotos', style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(4)),
        child: const Text('Falta', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
      );
    }
  }

  /// Diálogo de inscripción: buscar un estudiante ya existente en el catálogo
  /// global, o registrar uno nuevo si todavía no existe.
  void _mostrarDialogoNuevoEstudiante() {
    final formKey = GlobalKey<FormState>();
    final codigoController = TextEditingController();
    final nombreController = TextEditingController();

    bool modoNuevo = false;
    String? idEstudianteSeleccionado;
    bool guardando = false;
    String? errorDialogo;

    // Solo ofrecemos en el buscador a quienes NO están ya inscritos aquí.
    final idsYaInscritos = _inscritos.map((e) => e['id_estudiante'].toString()).toSet();
    final disponibles = _catalogoGlobal.where((s) => !idsYaInscritos.contains(s['id'].toString())).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> guardar() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() {
                guardando = true;
                errorDialogo = null;
              });
              try {
                String idEstudianteFinal;
                if (modoNuevo) {
                  final nuevo = await ApiService().createStudent(
                    codigoEstudiante: codigoController.text.trim(),
                    nombreCompleto: nombreController.text.trim(),
                  );
                  idEstudianteFinal = nuevo['id'].toString();
                } else {
                  idEstudianteFinal = idEstudianteSeleccionado!;
                }

                await ApiService().enrollStudent(
                  sectionId: widget.sectionId,
                  studentId: idEstudianteFinal,
                );

                if (!mounted) return;
                Navigator.pop(dialogContext);
                _cargarDatos();
              } catch (e) {
                setDialogState(() {
                  guardando = false;
                  errorDialogo = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              surfaceTintColor: Colors.transparent,
              title: const Text('INSCRIBIR ESTUDIANTE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(() => modoNuevo = false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !modoNuevo ? _colorMorado.withOpacity(0.1) : null,
                                side: BorderSide(color: !modoNuevo ? _colorMorado : Colors.grey[300]!),
                              ),
                              child: Text('Ya existe', style: TextStyle(color: !modoNuevo ? _colorMorado : Colors.black54, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setDialogState(() => modoNuevo = true),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: modoNuevo ? _colorMorado.withOpacity(0.1) : null,
                                side: BorderSide(color: modoNuevo ? _colorMorado : Colors.grey[300]!),
                              ),
                              child: Text('Nuevo', style: TextStyle(color: modoNuevo ? _colorMorado : Colors.black54, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!modoNuevo) ...[
                        Text('Escriba el nombre para buscar en el catálogo de la facultad.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 12),
                        const Text('Nombre completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Autocomplete<Map<String, dynamic>>(
                          displayStringForOption: (s) => s['nombre_completo']?.toString() ?? '',
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable.empty();
                            return disponibles.where((s) => (s['nombre_completo']?.toString() ?? '')
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (s) {
                            idEstudianteSeleccionado = s['id'].toString();
                          },
                          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: _buildInputDecoration('Escriba para buscar alumno...'),
                              validator: (v) {
                                if (modoNuevo) return null;
                                if (v == null || v.isEmpty) return 'Campo requerido';
                                if (idEstudianteSeleccionado == null) {
                                  return 'Selecciona un estudiante de la lista';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ] else ...[
                        const Text('Código de estudiante', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: codigoController,
                          decoration: _buildInputDecoration('Ej. 20210123'),
                          validator: (v) => modoNuevo && (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        const Text('Nombre completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nombreController,
                          decoration: _buildInputDecoration('Ej. Torres Lazo, Mariana'),
                          validator: (v) => modoNuevo && (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                        ),
                      ],

                      if (errorDialogo != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorDialogo!, style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: guardando ? null : guardar,
                  style: ElevatedButton.styleFrom(backgroundColor: _colorMorado, elevation: 0),
                  child: guardando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Inscribir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final alumnosFiltrados = _inscritos.where((est) {
      return (est['nombre']?.toString() ?? '').toLowerCase().contains(_filtroBusqueda.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Estudiantes', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Actualizar',
            onPressed: _cargarDatos,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.seccion} - ${widget.nombreCurso}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: TextFormField(
                        controller: _searchController,
                        decoration: _buildInputDecoration('Buscar estudiante...').copyWith(
                          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.black38),
                        ),
                        onChanged: (v) => setState(() => _filtroBusqueda = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: _colorMorado, borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      onPressed: _cargando ? null : _mostrarDialogoNuevoEstudiante,
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_cargando)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Colors.black12)),
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 880,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            color: const Color(0xFFFAFAFA),
                            child: const Row(
                              children: [
                                SizedBox(width: 40, child: SizedBox()),
                                Expanded(child: Text('NOMBRE COMPLETO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                SizedBox(width: 100, child: Text('CÓDIGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54))),
                                SizedBox(width: 140, child: Text('EMBEDDINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54), textAlign: TextAlign.center)),
                                SizedBox(width: 160, child: SizedBox()),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.black12),

                          alumnosFiltrados.isEmpty
                              ? const Padding(padding: EdgeInsets.all(32), child: Text("No se encontraron estudiantes"))
                              : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: alumnosFiltrados.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            itemBuilder: (context, index) {
                              final est = alumnosFiltrados[index];
                              final String nombre = est['nombre']?.toString() ?? '';
                              final int fotos = (est['fotos'] ?? 0) as int;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: _colorMorado.withOpacity(0.15),
                                        child: Text(_obtenerInicialesSeguras(nombre), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _colorMorado)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    SizedBox(width: 100, child: Text(est['codigo']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Colors.black54))),
                                    SizedBox(width: 140, child: Center(child: _buildEmbeddingStatus(fotos))),
                                    SizedBox(
                                      width: 160,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EmbeddingsAdminScreen(
                                                  studentId: est['id_estudiante'].toString(),
                                                  nombreAlumno: nombre,
                                                  seccion: widget.seccion,
                                                  nombreCurso: widget.nombreCurso,
                                                ),
                                              ),
                                            ),
                                            icon: const Icon(Icons.fingerprint, size: 14, color: Colors.black54),
                                            label: const Text('Embeddings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _retirarEstudiante(est),
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

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _colorMorado, width: 1.5)),
    );
  }
}