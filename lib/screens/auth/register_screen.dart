import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'login_screen.dart';
import '../widgets/animated_background.dart'; // AJUSTA LA RUTA A LA TUYA

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

  String _generarCodigoEmpresa() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _registerUser() async {
    if (_nombreCtrl.text.isEmpty ||
        _apellidoCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
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
          await FirebaseAuth.instance.currentUser?.delete().catchError((_) {});
          setState(() => _loading = false);
          return;
        }

        final codigoEmpresa = _generarCodigoEmpresa();
        final empresaRef =
            FirebaseFirestore.instance.collection('empresas').doc(codigoEmpresa);

        await empresaRef.set({
          'nombre': empresaNombre,
          'codigo': codigoEmpresa,
          'adminUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await empresaRef.collection('productos').doc('default').set({
          'init': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await empresaRef.collection('Clientes').doc('default').set({
          'init': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await empresaRef.collection('pedidos').doc('default').set({
          'init': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await empresaRef.collection('movimientos').doc('default').set({
          'init': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await usersRef.doc(uid).set({
          'nombre': nombre,
          'apellido': apellido,
          'email': email,
          'role': 'admin',
          'empresaCodigo': codigoEmpresa,
          'empresaNombre': empresaNombre,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final codigo = _codigoCtrl.text.trim();

        if (codigo.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes ingresar el código de la empresa.')),
          );
          await FirebaseAuth.instance.currentUser?.delete().catchError((_) {});
          setState(() => _loading = false);
          return;
        }

        final empresaSnap = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(codigo)
            .get();

        if (!empresaSnap.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El código de empresa no es válido.')),
          );
          await FirebaseAuth.instance.currentUser?.delete().catchError((_) {});
          setState(() => _loading = false);
          return;
        }

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
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: ${e.code} — ${e.message}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ListView(
              children: [
                const SizedBox(height: 20),

                // --- TÍTULO ---
                const Text(
                  "Crear Cuenta",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  "Regístrate para continuar.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 32),

                _input("Nombre", _nombreCtrl),
                const SizedBox(height: 16),

                _input("Apellido", _apellidoCtrl),
                const SizedBox(height: 16),

                _input("Correo electrónico", _emailCtrl,
                    keyboard: TextInputType.emailAddress),
                const SizedBox(height: 16),

                _input("Contraseña", _passCtrl, obscure: true),
                const SizedBox(height: 16),

                // ------------------- ROL -------------------
                Row(
                  children: [
                    const Text(
                      "Rol:",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      dropdownColor: Colors.black87,
                      value: _selectedRole,
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(
                            value: 'repartidor',
                            child: Text('Repartidor', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'ventanilla',
                            child: Text('Ventanilla', style: TextStyle(color: Colors.white))),
                        DropdownMenuItem(
                            value: 'admin',
                            child: Text('Administrador', style: TextStyle(color: Colors.white))),
                      ],
                      onChanged: (v) => setState(() => _selectedRole = v!),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedRole == "admin"
                      ? _input("Nombre de la empresa", _empresaCtrl)
                      : _input("Código de la empresa", _codigoCtrl),
                ),

                const SizedBox(height: 32),

                // ---------------- BOTÓN ----------------
                ElevatedButton(
                  onPressed: _loading ? null : _registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text("Crear cuenta", style: TextStyle(fontSize: 16)),
                ),

                const SizedBox(height: 24),

                // ---- YA TIENES CUENTA ----
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("¿Ya tienes una cuenta?",
                        style: TextStyle(color: Colors.white)),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text(
                        "Inicia sesión",
                        style: TextStyle(
                          color: Color.fromARGB(255, 2, 43, 76),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // WIDGET INPUT ESTILO LOGIN
  // ======================================================
  Widget _input(String hint, TextEditingController ctrl,
      {bool obscure = false, TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}
