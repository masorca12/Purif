import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final empresaCtrl = TextEditingController();
  final codigoCtrl = TextEditingController();
  String selectedRole = 'repartidor'; // Repartidor o Ventanilla
  bool loading = false;

  String generarCodigoEmpresa() {
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> register() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    setState(() => loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = cred.user!.uid;
      final usersRef = FirebaseFirestore.instance.collection('users');

      if (selectedRole == 'admin') {
        // Crear empresa y guardar código
        final codigoEmpresa = generarCodigoEmpresa();
        await FirebaseFirestore.instance.collection('empresas').doc(codigoEmpresa).set({
          'nombre': empresaCtrl.text.trim(),
          'codigo': codigoEmpresa,
          'adminUid': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Guardar usuario
        await usersRef.doc(uid).set({
          'email': email,
          'role': 'admin',
          'empresaCodigo': codigoEmpresa,
          'empresaNombre': empresaCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Repartidor o ventanilla: verificar código de empresa
        final codigo = codigoCtrl.text.trim();
        final empresaSnap = await FirebaseFirestore.instance.collection('empresas').doc(codigo).get();
        if (!empresaSnap.exists) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Código de empresa inválido')));
          await cred.user!.delete();
          setState(() => loading = false);
          return;
        }
        await usersRef.doc(uid).set({
          'email': email,
          'role': selectedRole,
          'empresaCodigo': codigo,
          'empresaNombre': empresaSnap['nombre'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Registrarse')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Correo')),
            SizedBox(height: 8),
            TextField(controller: passCtrl, decoration: InputDecoration(labelText: 'Contraseña'), obscureText: true),
            SizedBox(height: 12),
            Row(
              children: [
                Text('Rol: '),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedRole,
                  items: [
                    DropdownMenuItem(value: 'repartidor', child: Text('Repartidor')),
                    DropdownMenuItem(value: 'ventanilla', child: Text('Ventanilla')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (selectedRole == 'admin')
              TextField(controller: empresaCtrl, decoration: InputDecoration(labelText: 'Nombre de la empresa')),
            if (selectedRole != 'admin')
              TextField(controller: codigoCtrl, decoration: InputDecoration(labelText: 'Código de la empresa')),
            SizedBox(height: 16),
            ElevatedButton(onPressed: loading ? null : register,
                child: loading ? CircularProgressIndicator() : Text('Crear cuenta')),
          ],
        ),
      ),
    );
  }
}
