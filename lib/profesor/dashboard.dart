import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'profesor_drawer.dart';

class DashboardProfesor extends StatefulWidget {
  const DashboardProfesor({super.key});

  @override
  State<DashboardProfesor> createState() => _DashboardProfesorState();
}

class _DashboardProfesorState extends State<DashboardProfesor>
    with TickerProviderStateMixin {
  // ─── Constantes de color ───────────────────────────────────────────────────
  static const Color _primary      = Color(0xFF800404);
  static const Color _primaryDark  = Color(0xFF610202);
          static const Color _primaryLight = Color(0xFFAB4646);
  static const Color _surface      = Color(0xFFF4F2FF);

  // ─── Estado ───────────────────────────────────────────────────────────────
  List<dynamic> _secciones = [];
  bool _cargando = true;

  // Porcentajes de asistencia simulados por sección (índice → porcentaje)
  final List<double> _asistenciaSimulada = [0.82, 0.67, 0.91, 0.74];

  // Controladores de animación para cada tarjeta
  List<AnimationController> _cardControllers = [];
  List<Animation<double>>   _fadeAnimations  = [];
  List<Animation<Offset>>   _slideAnimations = [];

  // ─── Datos mock ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _seccionesSimuladas = [
    {
      'id': '00000000-0000-0000-0000-000000000000',
      'codigo_seccion': 'G1',
      'aula': 'Aula 302',
      'total_inscritos': 35,
      'curso': {'codigo_curso': 'INF-321', 'nombre_curso': 'Planeamiento Estratégico'},
      'horario_formateado': 'Lun 08:00 - 10:00',
    },
    {
      'id': '11111111-1111-1111-1111-111111111111',
      'codigo_seccion': 'G2',
      'aula': 'Lab S-4',
      'total_inscritos': 28,
      'curso': {'codigo_curso': 'INF-412', 'nombre_curso': 'Diseño y Evaluación de Proyectos'},
      'horario_formateado': 'Mie 10:00 - 13:00',
    },
  ];

  // ─── Ciclo de vida ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargarSecciones();
  }

  @override
  void dispose() {
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Inicializa un AnimationController por cada tarjeta y los dispara en cascada
  void _inicializarAnimaciones(int cantidad) {
    // Limpiamos los previos si hubo un refresh
    for (final c in _cardControllers) {
      c.dispose();
    }
    _cardControllers = List.generate(
      cantidad,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _fadeAnimations = _cardControllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: c, curve: Curves.easeOut),
    ))
        .toList();
    _slideAnimations = _cardControllers
        .map((c) => Tween<Offset>(
      begin: const Offset(0.18, 0),
      end:   Offset.zero,
    ).animate(
      CurvedAnimation(parent: c, curve: Curves.easeOutCubic),
    ))
        .toList();

    // Dispara cada tarjeta con 120 ms de retraso respecto a la anterior
    for (int i = 0; i < cantidad; i++) {
      Future.delayed(Duration(milliseconds: 120 * i), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  // ─── Red ──────────────────────────────────────────────────────────────────
  Future<void> _cargarSecciones() async {
    setState(() => _cargando = true);
    try {
      final secciones = await ApiService().getSections();
      setState(() {
        _secciones = secciones;
        _cargando  = false;
      });
      _inicializarAnimaciones(_secciones.length);
    } catch (_) {
      // Sin conexión al backend: usamos datos simulados para no romper la UI.
      setState(() {
        _secciones = _seccionesSimuladas;
        _cargando  = false;
      });
      _inicializarAnimaciones(_secciones.length);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _obtenerDiaSemana(int dia) {
    const dias = {1: 'Lun', 2: 'Mar', 3: 'Mie', 4: 'Jue', 5: 'Vie', 6: 'Sab', 7: 'Dom'};
    return dias[dia] ?? 'Clase';
  }

  double _porcentajeParaSeccion(int index) {
    if (index < _asistenciaSimulada.length) return _asistenciaSimulada[index];
    return 0.75;
  }

  Color _colorPorcentaje(double pct) {
    if (pct >= 0.85) return const Color(0xFF4CAF50);
    if (pct >= 0.65) return const Color(0xFFFFC107);
    return const Color(0xFFEF5350);
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final String nombreUsuario =
        ApiService().nombreUsuario ?? 'Docente';

    return Scaffold(
      backgroundColor: _surface,
      drawer: const ProfesorDrawer(rutaActiva: '/profesor/dashboard'),

      // ── CustomScrollView con SliverAppBar colapsable ──────────────────────
      body: CustomScrollView(
        slivers: [
          // ── 1. Header con gradiente ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            stretch: true,
            backgroundColor: _primaryDark,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: _cargarSecciones,
                tooltip: 'Actualizar secciones',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              stretchModes: const [StretchMode.zoomBackground],
              background: _buildHeader(nombreUsuario),
              // Título visible solo cuando está colapsado
              /*title: const Text(
                'Facile Check-In',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              */
              titlePadding:
              const EdgeInsetsDirectional.only(start: 60, bottom: 16),
            ),
          ),

          // ── 2. Etiqueta de sección ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'MIS SECCIONES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  if (!_cargando)
                    Text(
                      '${_secciones.length} asignadas',
                      style: const TextStyle(fontSize: 12, color: Colors.black38),
                    ),
                ],
              ),
            ),
          ),

          // ── 3. Contenido: loader / vacío / lista ──────────────────────────
          if (_cargando)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _primary),
              ),
            )
          else if (_secciones.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final seccion = _secciones[index] as Map<String, dynamic>;
                    final pct     = _porcentajeParaSeccion(index);
                    return _buildCard(seccion, index, pct);
                  },
                  childCount: _secciones.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Widget: header expandido ─────────────────────────────────────────────
  Widget _buildHeader(String nombre) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [_primary, _primaryDark, _primaryLight],
        ),
      ),
      child: Stack(
        children: [
          // Círculo decorativo superior-derecho
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // Círculo decorativo inferior-izquierdo
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Contenido textual del header
          Positioned(
            bottom: 28,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Color(0xFF69F0AE), size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Portal Docente',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Hola, $nombre 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Selecciona una sección para tomar asistencia',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: tarjeta de sección ───────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> seccion, int index, double pct) {
    final curso = seccion['curso'] as Map<String, dynamic>;

    final String horario = seccion['horario_formateado'] as String? ??
        '${_obtenerDiaSemana(seccion['dia_semana'] as int? ?? 1)} '
            '${(seccion['hora_inicio'] as String? ?? '00:00').substring(0, 5)} - '
            '${(seccion['hora_fin'] as String? ?? '00:00').substring(0, 5)}';

    final Color colorPct = _colorPorcentaje(pct);
    final bool esActivo  = pct >= 0.65;

    // Animación de entrada: fade + slide (controlada por AnimationController)
    Widget card = FadeTransition(
      opacity: index < _fadeAnimations.length
          ? _fadeAnimations[index]
          : const AlwaysStoppedAnimation(1),
      child: SlideTransition(
        position: index < _slideAnimations.length
            ? _slideAnimations[index]
            : const AlwaysStoppedAnimation(Offset.zero),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            // Sombra doble: sombra difusa + sombra de color del acento
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: _primary.withOpacity(0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: _primaryLight.withOpacity(0.2),
              highlightColor: _primaryLight.withOpacity(0.08),
              onTap: () => Navigator.pushNamed(
                context,
                '/profesor/nueva_sesion',
                arguments: seccion['id'].toString(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Fila superior: código + chip de estado ──────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge de código de curso
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${curso['codigo_curso']} · Sec. ${seccion['codigo_seccion']}',
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        // Chip de estado (Activo / Bajo asistencia)
                        _buildChip(esActivo),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Nombre del curso ─────────────────────────────────
                    Text(
                      curso['nombre_curso'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ── Aula ─────────────────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Flexible (
                          child: Text(
                            seccion['aula'] as String? ?? 'Sin aula',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black45),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Barra de asistencia ───────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Asistencia promedio',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black45),
                            ),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorPct,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: Colors.black.withOpacity(0.06),
                            valueColor:
                            AlwaysStoppedAnimation<Color>(colorPct),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Fila inferior: horario + alumnos + botón ─────────
                    Row(
                      children: [
                        // Horario
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Flexible(
                          flex: 3,
                          child: Text(
                            horario,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Total inscritos
                        const Icon(Icons.people_alt_outlined,
                            size: 14, color: Colors.black38),
                        const SizedBox(width: 4),
                        Flexible(
                          flex: 2,
                          child: Text(
                            '${seccion['total_inscritos']} alumnos',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                        ),
                        const Spacer(),
                        // Botón acción
                        _buildBotonAsistencia(seccion),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return card;
  }

  // ─── Widget: chip de estado ───────────────────────────────────────────────
  Widget _buildChip(bool activo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activo
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            activo ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 12,
            color: activo ? const Color(0xFF388E3C) : const Color(0xFFF57C00),
          ),
          const SizedBox(width: 4),
          Text(
            activo ? 'Activo' : 'Bajo asistencia',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: activo
                  ? const Color(0xFF388E3C)
                  : const Color(0xFFF57C00),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget: botón tomar asistencia ──────────────────────────────────────
  Widget _buildBotonAsistencia(Map<String, dynamic> seccion) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(
            context,
            '/profesor/nueva_sesion',
            arguments: seccion['id'].toString(),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text(
                  'Asistencia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Widget: estado vacío ─────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.black.withOpacity(0.15)),
            const SizedBox(height: 16),
            const Text(
              'Sin secciones asignadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contacta a tu administrador para que te asigne cursos este ciclo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}