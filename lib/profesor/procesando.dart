import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProcesandoAsistencia extends StatefulWidget {
  const ProcesandoAsistencia({super.key});

  @override
  State<ProcesandoAsistencia> createState() => _ProcesandoAsistenciaState();
}

class _ProcesandoAsistenciaState extends State<ProcesandoAsistencia> {
  final Color _colorMorado = const Color(0xFF766BE3);

  double _porcentaje = 0.05;
  String _etapaActual = "Subiendo imagen al servidor...";
  String? _error;
  Timer? _timer;
  String _idSesionRecibida = '';

  // Textos de progreso cosméticos: el estado real siempre viene del backend
  // (GET /sessions/{id}/status), esto solo anima la barra mientras esperamos.
  final List<String> _etapasVisuales = [
    "Detectando rostros en la panorámica...",
    "Recortando encuadres de estudiantes...",
    "Generando firmas numéricas vectoriales (ArcFace)...",
    "Contrastando embeddings con la base biométrica...",
  ];

  @override
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final args = ModalRoute.of(context)?.settings.arguments;
      String idSesion = '';

      if (args is String) {
        idSesion = args;
      } else if (args is Map && args.containsKey('id_sesion')) {
        idSesion = args['id_sesion'].toString();
      } else if (args is Map && args.containsKey('id')) {
        idSesion = args['id'].toString();
      }

      setState(() {
        _idSesionRecibida = idSesion;
      });

      if (idSesion.isEmpty) {
        setState(() {
          _error = 'No se recibió el ID de la sesión a procesar.';
        });
        return;
      }

      _iniciarPollingReal(idSesion);
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // ✨ CORREGIDO: Cancelación segura si la instancia existe
    super.dispose();
  }

  void _iniciarPollingReal(String idSesion) {
    int tick = 0;

    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final estado = await ApiService().getSessionStatus(idSesion);
        final String statusProceso = estado['status_proceso']?.toString() ?? 'processing';

        if (statusProceso == 'completed') {
          timer.cancel();
          setState(() => _porcentaje = 1.0);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/profesor/resultados',
            arguments: idSesion,
          );
          return;
        }

        if (statusProceso == 'failed') {
          timer.cancel();
          setState(() {
            _error = (estado['error']?.toString().isNotEmpty ?? false)
                ? estado['error'].toString()
                : 'El procesamiento falló en el servidor.';
          });
          return;
        }

        // Sigue "pending" o "processing": animamos el progreso visualmente
        // mientras esperamos a que el backend termine.
        setState(() {
          _porcentaje = (0.15 + (tick * 0.08)).clamp(0.0, 0.92);
          _etapaActual = _etapasVisuales[tick % _etapasVisuales.length];
        });
        tick++;
      } catch (e) {
        timer.cancel();
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'No se pudo procesar la asistencia',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.popUntil(
                              context,
                              ModalRoute.withName('/profesor/dashboard'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _colorMorado,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Volver a Mis secciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_colorMorado),
                        strokeWidth: 3.5,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Analizando imagen panorámica...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _etapaActual,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _porcentaje,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(_colorMorado),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Text(
                            "${(_porcentaje * 100).toInt()}%",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _colorMorado),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9C4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBC02D), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF57F17), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No cierres esta página. El proceso tarda entre 10 y 30 segundos.',
                        style: TextStyle(fontSize: 13, color: Colors.amber[900], fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}