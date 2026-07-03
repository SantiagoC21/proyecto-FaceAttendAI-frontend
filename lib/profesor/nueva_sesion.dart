import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class NuevaSesion extends StatefulWidget {
  const NuevaSesion({super.key});

  @override
  State<NuevaSesion> createState() => _NuevaSesionState();
}

class _NuevaSesionState extends State<NuevaSesion> {
  final Color _color = const Color(0xFF800404);
  final ImagePicker _picker = ImagePicker();
  File? _imagenSeleccionada;
  bool _enviando = false;

  // ── Estado de la sesión creada al entrar a la pantalla ──
  String _idSeccionOrigen = '';
  bool _creandoSesion = true;
  String? _errorCreacion;
  String? _idSesionCreada;
  String? _fechaSesionCreada;   // 'YYYY-MM-DD' que devuelve el backend
  String? _capturaTimestamp;    // datetime completo que devuelve el backend

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final String idSeccion = ModalRoute.of(context)?.settings.arguments as String? ??
          '00000000-0000-0000-0000-000000000000';
      _idSeccionOrigen = idSeccion;
      _crearSesionInicial(idSeccion);
    });
  }

  /// Se ejecuta al entrar a la pantalla (y al reintentar): crea la sesión
  /// en el backend mostrando un modal bloqueante mientras espera.
  /// Mapea a: POST /sessions/
  Future<void> _crearSesionInicial(String idSeccion) async {
    setState(() {
      _creandoSesion = true;
      _errorCreacion = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: _color),
              ),
              const SizedBox(width: 18),
              const Text(
                'Creando sesión...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final String fechaHoy = DateTime.now().toIso8601String().split('T')[0];
      final sesionCreada = await ApiService().createSession(
        idSeccion: idSeccion,
        fechaSesion: fechaHoy,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cierra el modal

      setState(() {
        _idSesionCreada = sesionCreada['id'].toString();
        _fechaSesionCreada = sesionCreada['fecha_sesion']?.toString() ?? fechaHoy;
        _capturaTimestamp = sesionCreada['capture_timestamp']?.toString();
        _creandoSesion = false;
      });
    } on SessionAlreadyExistsException catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cierra el modal "Creando sesión..."
      setState(() => _creandoSesion = false);
      _manejarSesionDuplicada(idSeccion);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cierra el modal
      setState(() {
        _creandoSesion = false;
        _errorCreacion = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Se dispara cuando POST /sessions/ responde 409 (ya existe sesión hoy).
  /// Busca los datos de esa sesión existente y ofrece anularla para reintentar.
  Future<void> _manejarSesionDuplicada(String idSeccion) async {
    Map<String, dynamic>? sesionExistente;
    try {
      final historial = await ApiService().getSectionHistory(idSeccion);
      final String fechaHoy = DateTime.now().toIso8601String().split('T')[0];
      sesionExistente = historial.firstWhere(
            (s) => s['fecha_sesion']?.toString() == fechaHoy && s['estado']?.toString() == 'activa',
        orElse: () => <String, dynamic>{},
      );
      if (sesionExistente.isEmpty) sesionExistente = null;
    } catch (_) {
      sesionExistente = null;
    }

    if (!mounted) return;

    final bool? confirmoAnular = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _buildModalSesionExistente(dialogContext, sesionExistente),
    );

    if (confirmoAnular != true || sesionExistente == null) {
      setState(() {
        _errorCreacion = 'Ya existe una sesión de hoy para esta sección.';
      });
      return;
    }

    try {
      await ApiService().annulSession(sesionExistente['id'].toString());
      await _crearSesionInicial(idSeccion);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCreacion = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildModalSesionExistente(BuildContext dialogContext, Map<String, dynamic>? sesion) {
    final bool tieneDatos = sesion != null;
    final String statusProceso = sesion?['status_proceso']?.toString() ?? '';
    final int presentes = (sesion?['total_presentes'] ?? 0) as int;
    final int inscritos = (sesion?['total_inscritos'] ?? 0) as int;
    final bool yaCompletada = statusProceso == 'completed';

    String mensaje;
    if (!tieneDatos) {
      mensaje = 'Ya existe una sesión registrada hoy para esta sección. ¿Deseas anularla y crear una nueva?';
    } else if (yaCompletada) {
      mensaje = 'Esta sección ya tiene una sesión de hoy procesada, con $presentes de $inscritos '
          'estudiantes presentes. ¿Deseas anularla y crear una nueva?';
    } else {
      mensaje = 'Esta sección ya tiene una sesión de hoy sin completar (estado: $statusProceso). '
          '¿Deseas anularla y crear una nueva?';
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          const Expanded(child: Text('Ya existe una sesión de hoy', style: TextStyle(fontSize: 16))),
        ],
      ),
      content: Text(mensaje, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text('Anular y crear de nuevo', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _capturarConCamara() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto != null) {
      setState(() => _imagenSeleccionada = File(foto.path));
    }
  }

  Future<void> _seleccionarDeGaleria() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.gallery);
    if (foto != null) {
      setState(() => _imagenSeleccionada = File(foto.path));
    }
  }

  Future<void> _enviarAsistencia() async {
    if (_imagenSeleccionada == null || _idSesionCreada == null) return;
    setState(() => _enviando = true);

    try {
      await ApiService().uploadPanorama(
        sessionId: _idSesionCreada!,
        imagen: _imagenSeleccionada!,
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/profesor/procesando',
        arguments: _idSesionCreada,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      appBar: AppBar(
        title: const Text(
          'Nueva sesión',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: _color,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SafeArea(
        child: _errorCreacion != null
            ? _buildErrorCreacion()
            : _creandoSesion
            ? const SizedBox.shrink()
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPaso1(),

                    const SizedBox(height: 8),
                    _buildDivisor(),
                    const SizedBox(height: 8),

                    _buildPaso2(),

                    const SizedBox(height: 20),

                    _buildOpcionCaptura(
                      onTap: _enviando ? null : _capturarConCamara,
                      icono: Icons.camera_alt_rounded,
                      titulo: 'Capturar con la cámara',
                      subtitulo: 'Recomendado',
                      resaltado: true,
                    ),

                    const SizedBox(height: 12),

                    _buildOpcionCaptura(
                      onTap: _enviando ? null : _seleccionarDeGaleria,
                      icono: Icons.collections_rounded,
                      titulo: 'Seleccionar de galería',
                      subtitulo: 'jpg, png — máx. 10 MB',
                      resaltado: false,
                    ),

                    if (_imagenSeleccionada != null) ...[
                      const SizedBox(height: 20),
                      _buildVistaPrevia(),
                    ],

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            _buildBarraInferior(),
          ],
        ),
      ),
    );
  }

  // ─── ERROR AL CREAR LA SESIÓN ─────────────────────────────────────────────
  Widget _buildErrorCreacion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No se pudo crear la sesión',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorCreacion!,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Volver'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _crearSesionInicial(_idSeccionOrigen),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── PASO 1 ───────────────────────────────────────────────────────────────
  Widget _buildPaso1() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paso 1 — Sesión creada',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.black38),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _formatearFechaHora(),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black45),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID de sesión', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(
                      _idSesionCreada ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A3FA0),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatearFechaHora() {
    if (_capturaTimestamp != null) {
      try {
        final dt = DateTime.parse(_capturaTimestamp!).toLocal();
        return '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year} — '
            '${dt.hour.toString().padLeft(2, '0')}:'
            '${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return _fechaSesionCreada ?? '—';
  }

  // ─── DIVISOR ──────────────────────────────────────────────────────────────
  Widget _buildDivisor() {
    return Row(
      children: [
        const SizedBox(width: 14),
        Container(width: 1, height: 20, color: Colors.black12),
      ],
    );
  }

  // ─── PASO 2 ───────────────────────────────────────────────────────────────
  Widget _buildPaso2() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              '2',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paso 2 — Capturar imagen panorámica',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              SizedBox(height: 4),
              Text(
                'Toma o sube una foto del salón para procesar la asistencia automáticamente.',
                style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── OPCIONES DE CAPTURA ──────────────────────────────────────────────────
  Widget _buildOpcionCaptura({
    required VoidCallback? onTap,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required bool resaltado,
  }) {
    final Color borderColor =
    resaltado ? _color : Colors.grey.shade300;
    final Color bgColor =
    resaltado ? _color.withOpacity(0.05) : Colors.white;
    final Color iconColor =
    resaltado ? _color : Colors.grey.shade400;
    final Color subtituloColor =
    resaltado ? _color : Colors.grey.shade500;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _color.withOpacity(0.08),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: subtituloColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.black26, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── VISTA PREVIA ─────────────────────────────────────────────────────────
  Widget _buildVistaPrevia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_rounded, size: 14, color: Colors.black45),
            const SizedBox(width: 6),
            const Text(
              'Vista previa',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black45),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _seleccionarDeGaleria,
              child: Text(
                'Cambiar',
                style: TextStyle(
                    fontSize: 12,
                    color: _color,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            _imagenSeleccionada!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF388E3C), size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Imagen lista para procesar',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF388E3C),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── BARRA INFERIOR ───────────────────────────────────────────────────────
  Widget _buildBarraInferior() {
    final bool puedeEnviar =
        _imagenSeleccionada != null && !_enviando && _idSesionCreada != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _enviando ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Cancelar',
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: puedeEnviar
                    ? const LinearGradient(
                  colors: [Color(0xFF766BE3), Color(0xFF4A3FA0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: puedeEnviar ? null : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                boxShadow: puedeEnviar
                    ? [
                  BoxShadow(
                    color: const Color(0xFF766BE3).withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: puedeEnviar ? () => _enviarAsistencia() : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _enviando
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Procesar asistencia',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: puedeEnviar
                              ? Colors.white
                              : Colors.grey.shade400,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}