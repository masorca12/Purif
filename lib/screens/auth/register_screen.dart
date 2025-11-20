import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();

  String _selectedRole = 'repartidor';
  bool _loading = false;

  // Generar código
  String _generarCodigoEmpresa() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Registro
  Future<void> _registerUser() async {
    if (_nombreCtrl.text.isEmpty ||
        _apellidoCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // Crear usuario
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );

      final uid = cred.user!.uid;
      final usersRef = FirebaseFirestore.instance.collection('users');

      final nombre = _nombreCtrl.text.trim();
      final apellido = _apellidoCtrl.text.trim();
      final email = _emailCtrl.text.trim();

      if (_selectedRole == 'admin') {
        final empresaNombre = _empresaCtrl.text.trim();

        if (empresaNombre.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes ingresar el nombre de la empresa.')),
          );

          // Evita crashear en Android
          await FirebaseAuth.instance.currentUser
              ?.delete()
              .catchError((_) {});

          setState(() => _loading = false);
          return;
        }

        final codigoEmpresa = _generarCodigoEmpresa();

        // Crear empresa
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(codigoEmpresa)
            .set({
          'nombre': empresaNombre,
          'codigo': codigoEmpresa,
          'adminUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Crear usuario admin
        await usersRef.doc(uid).set({
          'nombre': nombre,
          'apellido': apellido,
          'email': email,
          'role': 'admin',
          'empresaCodigo': codigoEmpresa,
          'empresaNombre': empresaNombre,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Si NO es admin
      else {
        final codigo = _codigoCtrl.text.trim();

        if (codigo.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes ingresar el código de la empresa.')),
          );

          await FirebaseAuth.instance.currentUser
              ?.delete()
              .catchError((_) {});
          setState(() => _loading = false);
          return;
        }

        // Validar empresa
        final empresaSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(codigo)
            .get();

        if (!empresaSnap.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El código de empresa no es válido.')),
          );

          await FirebaseAuth.instance.currentUser
              ?.delete()
              .catchError((_) {});
          setState(() => _loading = false);
          return;
        }

        // Registrar usuario normal
        await usersRef.doc(uid).set({
          'nombre': nombre,
          'apellido': apellido,
          'email': email,
          'role': _selectedRole,
          'empresaCodigo': codigo,
          'empresaNombre': empresaSnap['nombre'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }  on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ERROR FIREBASE AUTH: ${e.code} – ${e.message}'),
        ),
      );
      print('🔥 ERROR AUTH: ${e.code} – ${e.message}');
    }
       finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _empresaCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: Text('Crear cuenta',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ListView(
          children: [
            const SizedBox(height: 24),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apellidoCtrl,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 16),

            // Rol
            Row(
              children: [
                Text('Rol:',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(
                        value: 'repartidor', child: Text('Repartidor')),
                    DropdownMenuItem(
                        value: 'ventanilla', child: Text('Ventanilla')),
                    DropdownMenuItem(
                        value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
              ],
            ),

            const SizedBox(height: 16),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _selectedRole == 'admin'
                  ? TextField(
                      key: const ValueKey('empresa'),
                      controller: _empresaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la empresa',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    )
                  : TextField(
                      key: const ValueKey('codigo'),
                      controller: _codigoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Código de la empresa',
                        prefixIcon: Icon(Icons.vpn_key_outlined),
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _registerUser,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: const Color(0xFF0066FF),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Crear cuenta',
                        style: GoogleFonts.inter(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("¿Ya tienes una cuenta?"),
                TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  child: const Text(
                    'Inicia sesión',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
