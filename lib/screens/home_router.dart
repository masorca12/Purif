import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importa las pantallas de cada rol
import '../screens/auth/repartidor/repartidor_home.dart';
import '../screens/auth/administrador/admin_home.dart';
import '../screens/auth/ventanilla/ventanilla_home.dart';

class HomeRouter extends StatefulWidget {
  const HomeRouter({super.key});

  @override
  State<HomeRouter> createState() => _HomeRouterState();
}

class _HomeRouterState extends State<HomeRouter> {
  String? role;
  String? empresaCodigo;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  Future<void> fetchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      role = doc['role'];
      empresaCodigo = doc['empresaCodigo'];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (role) {
      case 'admin':
        return AdminHome(empresaCodigo: empresaCodigo!);
      case 'repartidor':
        return RepartidorHome(empresaCodigo: empresaCodigo!);
      case 'ventanilla':
        return VentanillaHome(empresaCodigo: empresaCodigo!);
      default:
        return const Scaffold(
          body: Center(child: Text('Rol no reconocido')),
        );
    }
  }
}
