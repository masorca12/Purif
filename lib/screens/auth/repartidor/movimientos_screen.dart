import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'movimiento_item.dart';

class MovimientosScreen extends StatelessWidget {
  final String empresaCodigo;

  const MovimientosScreen({super.key, required this.empresaCodigo});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("empresas")
          .doc(empresaCodigo)
          .collection("movimientos")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar movimientos"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No hay movimientos aún"));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;

            return MovimientoItem(
              producto: data["producto"] ?? "Sin nombre",
              salida: data["salida"] ?? false,
              entrada: data["entrada"] ?? false,
              cantidad: data["cantidad"] ?? 0,
              fecha: (data["createdAt"] as Timestamp).toDate(),
              refSalida: data["refSalida"],
            );
          },
        );
      },
    );
  }
}
