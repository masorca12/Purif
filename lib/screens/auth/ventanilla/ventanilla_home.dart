import 'package:flutter/material.dart';

class VentanillaHome extends StatelessWidget {
  final String empresaCodigo;

  const VentanillaHome({Key? key, required this.empresaCodigo})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Panel Ventanilla"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Comprobación"),
              Tab(text: "Pedidos"),
              Tab(text: "Ventas"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            Center(child: Text("Comprobación de salidas/entradas")),
            Center(child: Text("Agregar/mostrar pedidos")),
            Center(child: Text("Ventas en ventanilla")),
          ],
        ),
      ),
    );
  }
}
