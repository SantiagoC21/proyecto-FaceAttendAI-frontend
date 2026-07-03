  import 'package:flutter/material.dart';
import 'package:face_attend_ai/auth/login.dart';
import 'package:face_attend_ai/profesor/dashboard.dart' as prof;
import 'package:face_attend_ai/profesor/nueva_sesion.dart';
import 'package:face_attend_ai/profesor/historial.dart';
import 'package:face_attend_ai/profesor/procesando.dart';
import 'package:face_attend_ai/profesor/resultados.dart';
import 'package:face_attend_ai/profesor/verificacion.dart';

// Importamos los archivos del Administrador de forma limpia
import 'package:face_attend_ai/admin/dashboard.dart';
import 'package:face_attend_ai/admin/embeddings.dart';
import 'package:face_attend_ai/admin/cursos.dart';
import 'package:face_attend_ai/admin/secciones.dart';

void main() {
  runApp(const MiAppAsistencia());
}

class MiAppAsistencia extends StatelessWidget {
  const MiAppAsistencia({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facile Check-In',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF766BE3)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        // --- RUTAS DE AUTENTICACIÓN ---
        '/': (context) => Login(),

        // --- RUTAS DEL PROFESOR ---
        '/profesor/dashboard': (context) => const prof.DashboardProfesor(),
        '/profesor/nueva_sesion': (context) => const NuevaSesion(),
        '/profesor/historial': (context) => const Historial(),
        '/profesor/procesando': (context) => const ProcesandoAsistencia(),
        '/profesor/resultados': (context) => const ResultadosAsistencia(),

        // --- RUTAS DEL ADMINISTRADOR ---
        '/admin/dashboard': (context) => DashboardAdmin(),
        '/admin/cursos': (context) => const CursosAdminScreen(),
        '/admin/secciones': (context) => const SeccionesAdminScreen(),
        '/admin/embeddings': (context) => const EmbeddingsAdminScreen(),
      },
    );
  }
}

// ✨ MODIFICADO: Se eliminaron por completo las clases Mock (Secciones y Estudiantes) del fondo
// ya que ambas tienen ahora sus propios archivos reales y funcionales.