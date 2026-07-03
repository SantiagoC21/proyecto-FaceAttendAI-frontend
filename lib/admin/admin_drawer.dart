import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDrawer extends StatelessWidget {
  final String rutaActiva;

  const AdminDrawer({super.key, required this.rutaActiva});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Encabezado del menú
          Container(
            padding: const EdgeInsets.only(top: 60, bottom: 20, left: 24, right: 24),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Color(0xFF635BFF), size: 28),
                SizedBox(width: 12),
                Text(
                  'FacileCheckIn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Lista de Opciones de Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              children: [
                _buildMenuItem(context, 'Dashboard', Icons.dashboard_outlined, '/admin/dashboard'),
                _buildMenuItem(context, 'Cursos', Icons.assignment_outlined, '/admin/cursos'),
                _buildMenuItem(context, 'Secciones', Icons.book_outlined, '/admin/secciones'),
                _buildMenuItem(context, 'Embeddings', Icons.fingerprint, '/admin/embeddings'),
              ],
            ),
          ),

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
                Text(
                  ApiService().nombreUsuario ?? 'Administrador',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 2),
                Text(
                  ApiService().correoUsuario ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: () {
                    ApiService().logout();
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

  Widget _buildMenuItem(BuildContext context, String titulo, IconData icono, String rutaDestino) {
    final bool esActivo = rutaActiva == rutaDestino;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icono, color: esActivo ? const Color(0xFF635BFF) : Colors.black54, size: 22),
        title: Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            fontWeight: esActivo ? FontWeight.bold : FontWeight.w500,
            color: esActivo ? const Color(0xFF635BFF) : Colors.black54,
          ),
        ),
        selected: esActivo,
        selectedTileColor: const Color(0xFFF0EEFF),
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