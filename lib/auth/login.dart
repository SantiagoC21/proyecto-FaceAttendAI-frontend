import 'package:flutter/material.dart';
import '../services/api_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();

  late TabController _tabController;
  bool _ocultarPassword = true;
  bool _cargando = false;

  // Color corporativo unificado del portal docente y administrativo
  final Color _colorMoradoCorporativo = const Color(0xFF800404);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Gestiona la lógica de autenticación consumiendo el servicio unificado.
  Future<void> _procesarLogin() async {
    final correo = _correoController.text.trim();
    final password = _passwordController.text.trim();

    if (correo.isEmpty || password.isEmpty) {
      _mostrarAlerta('Por favor, llena todos los campos.');
      return;
    }

    setState(() {
      _cargando = true;
    });

    // Consumimos el metodo centralizado en el núcleo de red
    final resultado = await ApiService().login(correo: correo, password: password);
    final int pestanaActiva = _tabController.index;

    if (resultado['success'] == true) {
      final String rolDelBackend = resultado['rol'].toString().toLowerCase();

      // Validación cruzada entre pestaña de UI y rol del modelo de FastAPI
      if (pestanaActiva == 0 && rolDelBackend == 'teacher') {
        Navigator.pushReplacementNamed(context, '/profesor/dashboard');
      } else if (pestanaActiva == 1 && rolDelBackend == 'admin') {
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
      } else {
        _mostrarAlerta(
          'El rol asignado a este usuario ($rolDelBackend) no coincide con el perfil seleccionado.',
        );
      }
    } else {
      // --- PLAN B: MODO SIMULACIÓN ---
      // Si el ApiService falla porque el backend está apagado o inaccesible,
      // entramos en contingencia local para agilizar las pruebas del frontend.
      final mensajeError = resultado['message'] ?? '';
      if (mensajeError.contains('conexión') || mensajeError.contains('servidor')) {
        debugPrint('Backend inaccesible. Activando Plan B (Simulación local)...');

        if (pestanaActiva == 0) {
          Navigator.pushReplacementNamed(context, '/profesor/dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/admin/dashboard');
        }
      } else {
        // Si el backend sí respondió pero avisó un error de negocio (ej. contraseña incorrecta)
        _mostrarAlerta(mensajeError);
      }
    }

    setState(() {
      _cargando = false;
    });
  }

  void _mostrarAlerta(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aviso', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: _colorMoradoCorporativo)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/Uni-logo_transparente_granate.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'FaceAttend AI',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const Text(
                    'Control de Asistencia con reconocimiento facial',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Selector de Rol Institucional
                  TabBar(
                    controller: _tabController,
                    labelColor: _colorMoradoCorporativo,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: _colorMoradoCorporativo,
                    tabs: const [
                      Tab(icon: Icon(Icons.school_rounded), text: 'Profesor'),
                      Tab(icon: Icon(Icons.admin_panel_settings_rounded), text: 'Administrador'),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Entrada de Correo
                  TextField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo Institucional',
                      prefixIcon: const Icon(Icons.email_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Entrada de Contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText: _ocultarPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_ocultarPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Botón de Acción Principal
                  ElevatedButton(
                    onPressed: _cargando ? null : _procesarLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorMoradoCorporativo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _cargando
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text(
                      'INICIAR SESIÓN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Solo para personal autorizado',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}