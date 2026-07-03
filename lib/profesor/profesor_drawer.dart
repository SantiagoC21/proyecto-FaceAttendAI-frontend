import 'package:flutter/material.dart';

class ProfesorDrawer extends StatelessWidget {
  final String rutaActiva;

  const ProfesorDrawer({super.key, required this.rutaActiva});

  @override
  Widget build(BuildContext context) {
    // Unificamos el color morado corporativo principal
    const Color colorMorado = Color(0xFF766BE3);

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Encabezado del menú (Idéntico en estructura al de Admin)
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20, left: 24, right: 24),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Row(
              children: [
                Icon(Icons.school_outlined, color: colorMorado, size: 28),
                SizedBox(width: 12),
                Text(
                  'FacileCheckIn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Lista de Opciones de Navegación del Profesor
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildMenuItem(context, 'Mis secciones', Icons.apps_rounded, '/profesor/dashboard', colorMorado),
                _buildMenuItem(context, 'Historial', Icons.history_toggle_off_rounded, '/profesor/historial', colorMorado),
              ],
            ),
          ),

          // Sección Inferior Permanente (Mismo diseño premium con datos de Docente)
          // Sección Inferior Permanente
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
              color: Color(0xFFFAFAFA),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Carlos Mendoza',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  'carlos.mendoza@pucp.pe',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () {
                    // ✨ CORREGIDO: Usamos la ruta raíz '/' que es la que tu proyecto reconoce como Login
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  },
                  icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                  label: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.transparent),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String titulo, IconData icono, String rutaDestino, Color colorActivo) {
    final bool esActivo = rutaActiva == rutaDestino;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icono, color: esActivo ? colorActivo : Colors.black54, size: 22),
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: esActivo ? FontWeight.bold : FontWeight.w500,
            color: esActivo ? colorActivo : Colors.black54,
          ),
        ),
        selected: esActivo,
        selectedTileColor: const Color(0xFFF0EEFF), // Fondo sutil morado al estar seleccionado
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: () {
          if (!esActivo) {
            Navigator.pushReplacementNamed(context, rutaDestino);
          } else {
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}