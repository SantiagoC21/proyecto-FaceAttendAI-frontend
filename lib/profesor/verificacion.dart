import 'package:flutter/material.dart';
import '../services/api_service.dart';

class VerificacionManual extends StatefulWidget {
  final List<Map<String, dynamic>> alumnosIniciales;
  final String idSesion;

  const VerificacionManual({
    super.key,
    required this.alumnosIniciales,
    required this.idSesion,
  });

  @override
  State<VerificacionManual> createState() => _VerificacionManualState();
}

class _VerificacionManualState extends State<VerificacionManual> {
  final Color _colorMorado = const Color(0xFF766BE3);

  late List<Map<String, dynamic>> _todoElCatalogo;
  List<Map<String, dynamic>> _soloPendientes = [];
  int _indiceActual = 0;
  int _totalAIngresar = 0;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Clonamos la lista original para mantener la referencia limpia
    _todoElCatalogo = List<Map<String, dynamic>>.from(widget.alumnosIniciales);
    _filtrarPendientes();
    _totalAIngresar = _soloPendientes.length;
  }

  void _filtrarPendientes() {
    _soloPendientes = _todoElCatalogo.where((al) => al['estado'] == 'Revisión').toList();
  }

  Future<void> _procesarVoto(String nuevoEstado) async {
    if (_soloPendientes.isEmpty || _guardando) return;

    final alumnoVotado = _soloPendientes[_indiceActual];
    final String? idRegistro = alumnoVotado['id_registro']?.toString();

    if (idRegistro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este registro no tiene un ID válido para verificar.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // Persiste la decisión del profesor en el backend.
      // Mapea a: PATCH /sessions/{session_id}/results/{record_id}
      await ApiService().verifyAttendanceRecord(
        sessionId: widget.idSesion,
        recordId: idRegistro,
        status: nuevoEstado == 'Presente' ? 'present' : 'absent',
      );

      // 1. Buscamos al alumno en la lista global por su id de registro y actualizamos su estado
      final idxGlobal = _todoElCatalogo.indexWhere(
            (element) => element['id_registro']?.toString() == idRegistro,
      );
      if (idxGlobal != -1) {
        _todoElCatalogo[idxGlobal]['estado'] = nuevoEstado;
        _todoElCatalogo[idxGlobal]['verificado'] = 'Manual';
      }

      // 2. Volvemos a filtrar las revisiones restantes
      setState(() {
        _filtrarPendientes();
        _guardando = false;
        if (_indiceActual >= _soloPendientes.length && _soloPendientes.isNotEmpty) {
          _indiceActual = _soloPendientes.length - 1;
        }
      });

      // 3. Si ya no quedan alumnos pendientes en la lista filtrada, volvemos automáticamente
      if (_soloPendientes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Todos los registros han sido verificados!')),
        );
        Navigator.pop(context, _todoElCatalogo);
      }
    } catch (e) {
      setState(() => _guardando = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si la lista está vacía preventivamente antes del pop automático
    if (_soloPendientes.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final alumnoActual = _soloPendientes[_indiceActual];
    final double similitud = double.parse(alumnoActual['similitud'].replaceAll('%', ''));
    int revisados = _totalAIngresar - _soloPendientes.length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Verificación manual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: _colorMorado,
        // Al darle atrás de forma nativa en el AppBar, regresamos la lista modificada
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _todoElCatalogo),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ENCABEZADO SUPERIOR ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$revisados de $_totalAIngresar verificados',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber[300]!),
                    ),
                    child: Text(
                      '${_soloPendientes.length} pendientes',
                      style: TextStyle(color: Colors.amber[800], fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- TARJETA PRINCIPAL DE DECISIÓN ---
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alumnoActual['nombre'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFFFFDE7), borderRadius: BorderRadius.circular(20)),
                        child: Text('Similitud detectada: ${alumnoActual['similitud']}', style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'El sistema detectó este rostro pero con baja confianza (umbral mínimo: 50%). Confirma si el estudiante está presente.',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                      ),
                      const SizedBox(height: 25),
                      _buildSliderConfianza(similitud),
                      const SizedBox(height: 30),

                      // --- FILA DE BOTONES DE ESTADO (CORREGIDO: SOLO PRESENTE Y AUSENTE) ---
                      Row(
                        children: [
                          // Botón Presente
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _guardando ? null : () => _procesarVoto('Presente'),
                              icon: const Icon(Icons.check, color: Colors.white, size: 18),
                              label: const Text('Presente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00B050),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0
                              ),
                            ),
                          ),
                          const SizedBox(width: 12), // Un espacio un poco más holgado entre ambos
                          // Botón Ausente
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _guardando ? null : () => _procesarVoto('Ausente'),
                              icon: const Icon(Icons.close, color: Colors.red, size: 18),
                              label: const Text('Ausente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFFFCDD2)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // --- SECCIÓN INFERIOR: DINÁMICA DE PENDIENTES ---
              const Text('PENDIENTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _soloPendientes.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  itemBuilder: (context, index) {
                    final item = _soloPendientes[index];
                    bool esElSeleccionado = index == _indiceActual;

                    return Container(
                      color: esElSeleccionado ? _colorMorado.withAlpha(15) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['nombre'], style: TextStyle(fontSize: 14, fontWeight: esElSeleccionado ? FontWeight.bold : FontWeight.w500, color: esElSeleccionado ? _colorMorado : Colors.black87)),
                          Text(item['similitud'], style: TextStyle(fontSize: 14, fontWeight: esElSeleccionado ? FontWeight.bold : FontWeight.normal, color: Colors.grey[600])),
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

  Widget _buildSliderConfianza(double valor) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(height: 6, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [Color(0xFFEF9A9A), Color(0xFFFFF59D), Color(0xFFA5D6A7)], stops: [0.35, 0.65, 1.0]))),
            LayoutBuilder(
              builder: (context, constraints) {
                double posicionX = (valor / 100) * constraints.maxWidth;
                return Transform.translate(
                  offset: Offset(posicionX - 8, 0),
                  child: Container(width: 14, height: 14, decoration: BoxDecoration(color: const Color(0xFFFBC02D), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)])),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_textLabelSlider('Desconocido'), _textLabelSlider('Revisión'), _textLabelSlider('Confirmado')])
      ],
    );
  }

  Widget _textLabelSlider(String texto) => Text(texto, style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500));
}