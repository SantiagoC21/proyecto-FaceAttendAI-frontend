import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'admin_drawer.dart';

class EmbeddingsAdminScreen extends StatefulWidget {
  final String? studentId;
  final String nombreAlumno;
  final String seccion;
  final String nombreCurso;

  const EmbeddingsAdminScreen({
    super.key,
    this.studentId,
    this.nombreAlumno = 'General',
    this.seccion = '',
    this.nombreCurso = '',
  });

  @override
  State<EmbeddingsAdminScreen> createState() => _EmbeddingsAdminScreenState();
}

class _EmbeddingsAdminScreenState extends State<EmbeddingsAdminScreen> {
  final Color _colorMorado = const Color(0xFF766BE3);
  final ImagePicker _picker = ImagePicker();

  // ─── Estado de la lista (mismo patrón que estudiantes.dart) ────────────────
  List<Map<String, dynamic>> _embeddings = [];
  bool _cargando = true;
  String? _error;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) {
      _cargarDatos();
    } else {
      _cargando = false;
    }
  }

  // ─── Red (mismo patrón que _cargarDatos de estudiantes.dart) ───────────────
  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final embeddings = await ApiService().getEmbeddings(widget.studentId!);
      setState(() {
        _embeddings = embeddings;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _cargando = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ─── Igual patrón que _retirarEstudiante, pero elimina un embedding ────────
  Future<void> _eliminarEmbedding(Map<String, dynamic> emb) async {
    try {
      await ApiService().deleteEmbedding(emb['id'].toString());
      setState(() => _embeddings.remove(emb));
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

  // ─── Igual patrón que el botón "+" de estudiantes.dart, pero abre la cámara/galería directo ───
  Future<void> _agregarFotos() async {
    if (widget.studentId == null || _subiendo) return;
    try {
      final fotos = await _picker.pickMultiImage();
      if (fotos.isEmpty) return;

      setState(() => _subiendo = true);
      final List<String> errores = [];
      for (final foto in fotos) {
        try {
          await ApiService().registerEmbedding(
            studentId: widget.studentId!,
            imagen: File(foto.path),
          );
        } catch (e) {
          errores.add(e.toString().replaceFirst('Exception: ', ''));
        }
      }

      if (!mounted) return;
      setState(() => _subiendo = false);
      if (errores.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${errores.length} foto(s) fallaron: ${errores.first}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      _cargarDatos();
    } catch (e) {
      if (!mounted) return;
      setState(() => _subiendo = false);
      debugPrint("Error al seleccionar imágenes: $e");
    }
  }

  // ─── Igual patrón que _obtenerInicialesSeguras de estudiantes.dart ─────────
  String _formatearFecha(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.studentId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF9F9F9),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        drawer: const AdminDrawer(rutaActiva: '/admin/embeddings'),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'Selecciona un estudiante desde la pantalla "Estudiantes" para gestionar sus embeddings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black38, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Embeddings', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
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
              // ── Mismo patrón que el título de estudiantes.dart ──
              Text(
                '${widget.nombreAlumno}${widget.seccion.isNotEmpty ? ' — ${widget.seccion}' : ''}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              // ── Mismo patrón que la fila buscador + botón "+" de estudiantes.dart ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_embeddings.length} embedding(s) registrados',
                      style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(color: _colorMorado, borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      onPressed: (_cargando || _subiendo) ? null : _agregarFotos,
                      icon: _subiendo
                          ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.add_a_photo_outlined, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Mismo patrón de estados (cargando/error/tabla) que estudiantes.dart ──
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
                  child: _embeddings.isEmpty
                      ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text("Este estudiante todavía no tiene fotos registradas."),
                  )
                      : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _embeddings.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final emb = _embeddings[index];
                      final bool esPrimario = emb['es_primario'] == true;

                      // ── Misma fila que estudiantes.dart: avatar + texto expandido + acción ──
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: _colorMorado.withOpacity(0.15),
                              child: Icon(Icons.fingerprint, size: 16, color: _colorMorado),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(emb['modelo_version']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      if (esPrimario) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: _colorMorado.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                                          child: Text('Primario', style: TextStyle(fontSize: 10, color: _colorMorado, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(_formatearFecha(emb['created_at']?.toString()), style: const TextStyle(fontSize: 11, color: Colors.black38)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _eliminarEmbedding(emb),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Mismo _buildError que estudiantes.dart ─────────────────────────────
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
}