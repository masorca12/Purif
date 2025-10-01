import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RepartidorHome extends StatefulWidget {
  final String empresaCodigo;
  const RepartidorHome({Key? key, required this.empresaCodigo}) : super(key: key);

  @override
  _RepartidorHomeState createState() => _RepartidorHomeState();
}

class _RepartidorHomeState extends State<RepartidorHome> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final TextEditingController _cantidadController = TextEditingController();
  String? _productoSeleccionado;
  bool _isSalida = true;

  Future<void> _registrarMovimiento() async {
    if (_productoSeleccionado == null || _cantidadController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona producto y cantidad")),
      );
      return;
    }

    final cantidad = int.tryParse(_cantidadController.text) ?? 0;

    final productoDoc = FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("productos")
        .doc(_productoSeleccionado);

    final productoData = await productoDoc.get();
    if (!productoData.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto no encontrado")),
      );
      return;
    }

    // 🔹 Usamos 'stock' en lugar de 'cantidad'
final stock = productoData.data()?["stock"];
final currentStock = int.tryParse(stock?.toString() ?? "0") ?? 0;

    int nuevoStock = currentStock;
    if (_isSalida) {
      nuevoStock = currentStock - cantidad;
      if (nuevoStock < 0) nuevoStock = 0;
    } else {
      nuevoStock = currentStock + cantidad;
    }

    await productoDoc.update({"stock": nuevoStock});

    // Guardar movimiento
    await FirebaseFirestore.instance
        .collection("empresas")
        .doc(widget.empresaCodigo)
        .collection("movimientos")
        .add({
      "productoId": _productoSeleccionado,
      "cantidad": cantidad,
      "fecha": FieldValue.serverTimestamp(),
      "repartidorId": user?.uid,
      "tipo": _isSalida ? "salida" : "entrada",
    });

    _cantidadController.clear();
    setState(() {
      _productoSeleccionado = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Movimiento registrado")),
    );
  }

  Widget _buildMovimientosTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("empresas")
                .doc(widget.empresaCodigo)
                .collection("productos")
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              final productos = snapshot.data!.docs;

              return DropdownButton<String>(
                hint: const Text("Selecciona producto"),
                value: _productoSeleccionado,
                isExpanded: true,
                onChanged: (value) {
                  setState(() {
                    _productoSeleccionado = value;
                  });
                },
                items: productos.map((doc) {
                  final data = doc.data() as Map<String, dynamic>?; 
                  final stock = int.tryParse(data?["stock"]?.toString() ?? "0") ?? 0;
                  return DropdownMenuItem<String>(
                    value: doc.id,
                   child: Text("${doc["nombre"]} (Stock: $stock)"),
                  );
                }).toList(),
              );
            },
          ),
          TextField(
            controller: _cantidadController,
            decoration: const InputDecoration(labelText: "Cantidad"),
            keyboardType: TextInputType.number,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Radio<bool>(
                value: true,
                groupValue: _isSalida,
                onChanged: (value) {
                  setState(() {
                    _isSalida = true;
                  });
                },
              ),
              const Text("Salida"),
              Radio<bool>(
                value: false,
                groupValue: _isSalida,
                onChanged: (value) {
                  setState(() {
                    _isSalida = false;
                  });
                },
              ),
              const Text("Entrada"),
            ],
          ),
          ElevatedButton(
            onPressed: _registrarMovimiento,
            child: const Text("Registrar"),
          ),
        ],
      ),
    );
  }

  Widget _buildClientesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("empresas")
          .doc(widget.empresaCodigo)
          .collection("clientes")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final clientes = snapshot.data!.docs;

        return ListView.builder(
          itemCount: clientes.length,
          itemBuilder: (context, index) {
            final cliente = clientes[index];
            return ListTile(
              title: Text(cliente["nombre"]),
              subtitle: Text("Dirección: ${cliente["direccion"] ?? ''}"),
            );
          },
        );
      },
    );
  }

  Widget _buildReportesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("empresas")
          .doc(widget.empresaCodigo)
          .collection("reportes")
          .where("repartidorId", isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final reportes = snapshot.data!.docs;

        return ListView.builder(
          itemCount: reportes.length,
          itemBuilder: (context, index) {
            final reporte = reportes[index];
            return ListTile(
              title: Text("Cliente: ${reporte["cliente"]}"),
              subtitle: Text(
                "Vendidos: ${reporte["cantidadVendida"]} | Precio: ${reporte["precio"]}\n"
                "No aceptados: ${reporte["noAceptados"]}",
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPedidosTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("empresas")
          .doc(widget.empresaCodigo)
          .collection("pedidos")
          .where("estado", isEqualTo: "pendiente")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final pedidos = snapshot.data!.docs;

        return ListView.builder(
          itemCount: pedidos.length,
          itemBuilder: (context, index) {
            final pedido = pedidos[index];
            return ListTile(
              title: Text("Cliente: ${pedido["cliente"]}"),
              subtitle: Text("Producto: ${pedido["producto"]} - Cant: ${pedido["cantidad"]}"),
            );
          },
        );
      },
    );
  }

  final List<String> _tabs = [
    "Movimientos",
    "Clientes",
    "Reportes",
    "Pedidos"
  ];

  @override
  Widget build(BuildContext context) {
    final tabWidgets = [
      _buildMovimientosTab(),
      _buildClientesTab(),
      _buildReportesTab(),
      _buildPedidosTab(),
    ];

    return Scaffold(
      appBar: AppBar(title: Text("Repartidor - ${_tabs[_currentIndex]}")),
      body: tabWidgets[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _tabs
            .map((t) => BottomNavigationBarItem(icon: const Icon(Icons.list), label: t))
            .toList(),
        onTap: (i) {
          setState(() {
            _currentIndex = i;
          });
        },
      ),
    );
  }
}
