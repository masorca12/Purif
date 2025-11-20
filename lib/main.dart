import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async'; // Necesario para usar el Timer
import 'dart:math'; // Necesario para la rotación (pi)

// Asegúrate de que estas rutas de importación sean correctas para tu proyecto
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// --- WIDGET NUEVO: PANTALLA DE CARGA CON ANIMACIÓN PERSONALIZADA ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2500), // Duración total
      vsync: this,
    );

    // Animación para la rotación del círculo
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi * 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Animación para que el logo aparezca en la segunda mitad del tiempo
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    
    // Inicia la animación
    _controller.forward();

    // Navega a la pantalla de login después de 3 segundos
    Timer(const Duration(seconds: 3), () {
      if (mounted) { // Revisa si el widget todavía está en pantalla
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. El Círculo Giratorio
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: CustomPaint(
                    painter: CirclePainter(),
                    size: const Size(160, 160),
                  ),
                );
              },
            ),
            // 2. El Logo que aparece
            FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset('assets/images/logo.png', // ¡TU LOGO!
                width: 120,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CLASE NUEVA: EL PINTOR DEL CÍRCULO ---
// Esta clase se encarga de dibujar el arco giratorio
class CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00A9C3) // Un color azul/verde similar a tu logo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;

    // Dibuja un arco que cubre 3/4 del círculo para que se vea que gira
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      0, // Ángulo de inicio
      (3 * pi) / 2, // Cuánto del círculo dibujar (270 grados)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}


// --- CLASE PRINCIPAL 'MyApp' (SIN CAMBIOS) ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'admin',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/login': (_) => LoginScreen(),
        '/register': (_) => RegisterScreen(),
        '/home': (_) => HomeRouter(),
      },
    );
  }
}

