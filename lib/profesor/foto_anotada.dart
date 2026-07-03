import 'package:flutter/material.dart';
import '../models/attendance_models.dart';
import '../services/api_service.dart';
import 'foto_anotada.dart';

class FotoAnotadaCard extends StatefulWidget {
  final String panoramaUrl;
  final List<AttendanceRecord> records;

  const FotoAnotadaCard({super.key, required this.panoramaUrl, required this.records});

  @override
  State<FotoAnotadaCard> createState() => _FotoAnotadaCardState();
}

class _FotoAnotadaCardState extends State<FotoAnotadaCard> {
  final Color _colorMorado = const Color(0xFF766BE3);

  Size? _tamanoOriginal;
  bool _cargando = true;
  bool _error = false;

  String get _urlCompleta => widget.panoramaUrl.startsWith('http')
      ? widget.panoramaUrl
      : '${ApiService.baseUrl}${widget.panoramaUrl}';

  @override
  void initState() {
    super.initState();
    _resolverTamanoImagen();
  }

  void _resolverTamanoImagen() {
    final image = Image.network(_urlCompleta).image;
    image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (!mounted) return;
        setState(() {
          _tamanoOriginal = Size(info.image.width.toDouble(), info.image.height.toDouble());
          _cargando = false;
        });
      }, onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() {
          _cargando = false;
          _error = true;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image_search_rounded, size: 18, color: _colorMorado),
                const SizedBox(width: 8),
                const Text(
                  'Foto de la sesión',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildContenido(),
          ],
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_error) {
      return Container(
        height: 160,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.black26, size: 32),
            const SizedBox(height: 8),
            Text('No se pudo cargar la foto', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_cargando || _tamanoOriginal == null) {
      return Container(
        height: 220,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _colorMorado, strokeWidth: 2.5),
            const SizedBox(height: 12),
            Text('Cargando foto...', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }

    final detectados = widget.records.where((r) => r.boundingBox != null).toList();

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeIn,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: AspectRatio(
            aspectRatio: _tamanoOriginal!.width / _tamanoOriginal!.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double escalaX = constraints.maxWidth / _tamanoOriginal!.width;
                final double escalaY = constraints.maxHeight / _tamanoOriginal!.height;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(_urlCompleta, fit: BoxFit.fill),
                    CustomPaint(painter: _CajasPainter(detectados, escalaX, escalaY)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CajasPainter extends CustomPainter {
  final List<AttendanceRecord> registros;
  final double escalaX;
  final double escalaY;

  _CajasPainter(this.registros, this.escalaX, this.escalaY);

  @override
  void paint(Canvas canvas, Size size) {
    final paintCaja = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final r in registros) {
      final box = r.boundingBox!;
      final double x = (box['x'] as num).toDouble() * escalaX;
      final double y = (box['y'] as num).toDouble() * escalaY;
      final double w = (box['w'] as num).toDouble() * escalaX;
      final double h = (box['h'] as num).toDouble() * escalaY;
      final rect = Rect.fromLTWH(x, y, w, h);

      canvas.drawRect(rect, paintCaja);

      final String etiqueta = r.estudianteNombre ?? 'Sin identificar';
      final textPainter = TextPainter(
        text: TextSpan(
          text: etiqueta,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, backgroundColor: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(x, (y - 16).clamp(0, double.infinity)));
    }
  }

  @override
  bool shouldRepaint(covariant _CajasPainter oldDelegate) => false;
}